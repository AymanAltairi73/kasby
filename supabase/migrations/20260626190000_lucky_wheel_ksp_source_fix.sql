-- KSP Effective Balance System
-- Single formula: Effective KSP = FLOOR(wallet_usd * 1000) + reward_ksp
-- reward_ksp lives in user_points.current_balance (wheel, referrals, check-ins, etc.)
-- wallet_usd lives in wallets.available_balance (currency = 'USD')

COMMENT ON COLUMN public.user_points.current_balance IS
  'Reward KSP only (not wallet-backed). Effective KSP = FLOOR(wallet_usd*1000) + current_balance.';

-- ─── Read unified balance ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_get_effective_ksp(p_user_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_wallet_usd numeric(18, 4) := 0;
    v_reward_ksp integer := 0;
    v_wallet_ksp integer := 0;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    IF auth.uid() IS NOT NULL AND p_user_id <> auth.uid() AND NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Forbidden');
    END IF;

    SELECT COALESCE(w.available_balance, 0)
      INTO v_wallet_usd
      FROM public.wallets w
     WHERE w.user_id = p_user_id
       AND w.currency = 'USD'
     LIMIT 1;

    PERFORM public.ensure_user_points(p_user_id);

    SELECT COALESCE(up.current_balance, 0)
      INTO v_reward_ksp
      FROM public.user_points up
     WHERE up.user_id = p_user_id;

    v_wallet_ksp := FLOOR(v_wallet_usd * 1000)::integer;

    RETURN jsonb_build_object(
        'success', true,
        'wallet_usd', v_wallet_usd,
        'wallet_ksp', v_wallet_ksp,
        'reward_ksp', v_reward_ksp,
        'effective_ksp', v_wallet_ksp + v_reward_ksp
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_effective_ksp(uuid) TO authenticated;

-- ─── Credit reward KSP (wheel, referrals, check-in) ───────────────────────

CREATE OR REPLACE FUNCTION public.fn_credit_reward_ksp(
    p_user_id uuid,
    p_amount integer,
    p_description text,
    p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    IF p_user_id IS NULL OR p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid credit request');
    END IF;

    PERFORM public.ensure_user_points(p_user_id);

    UPDATE public.user_points
       SET current_balance = current_balance + p_amount,
           total_earned = total_earned + p_amount,
           updated_at = NOW()
     WHERE user_id = p_user_id;

    INSERT INTO public.point_history (user_id, points, type, description, reference_id)
    VALUES (p_user_id, p_amount, 'earn', p_description, p_reference_id);

    RETURN public.fn_get_effective_ksp(p_user_id)
        || jsonb_build_object('credited', p_amount);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_credit_reward_ksp(uuid, integer, text, text) TO authenticated;

-- ─── Deduct effective KSP (reward first, then wallet USD) ───────────────────

CREATE OR REPLACE FUNCTION public.fn_deduct_effective_ksp(
    p_user_id uuid,
    p_amount integer,
    p_description text,
    p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_wallet_id uuid;
    v_wallet_usd numeric(18, 4) := 0;
    v_reward_ksp integer := 0;
    v_wallet_ksp integer := 0;
    v_effective integer := 0;
    v_from_reward integer := 0;
    v_from_wallet_ksp integer := 0;
    v_usd_deduct numeric(18, 4) := 0;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid amount');
    END IF;

    PERFORM public.fn_assert_user_can_write(p_user_id);
    PERFORM public.ensure_user_points(p_user_id);

    SELECT w.id, COALESCE(w.available_balance, 0)
      INTO v_wallet_id, v_wallet_usd
      FROM public.wallets w
     WHERE w.user_id = p_user_id
       AND w.currency = 'USD'
       FOR UPDATE;

    SELECT COALESCE(up.current_balance, 0)
      INTO v_reward_ksp
      FROM public.user_points up
     WHERE up.user_id = p_user_id
       FOR UPDATE;

    v_wallet_ksp := FLOOR(v_wallet_usd * 1000)::integer;
    v_effective := v_wallet_ksp + v_reward_ksp;

    IF v_effective < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient points');
    END IF;

    v_from_reward := LEAST(v_reward_ksp, p_amount);
    v_from_wallet_ksp := p_amount - v_from_reward;
    v_usd_deduct := v_from_wallet_ksp / 1000.0;

    IF v_from_reward > 0 THEN
        UPDATE public.user_points
           SET current_balance = current_balance - v_from_reward,
               updated_at = NOW()
         WHERE user_id = p_user_id;
    END IF;

    UPDATE public.user_points
       SET total_spent = total_spent + p_amount,
           updated_at = NOW()
     WHERE user_id = p_user_id;

    IF v_usd_deduct > 0 THEN
        IF v_wallet_id IS NULL THEN
            RAISE EXCEPTION 'Wallet not found for KSP wallet deduction';
        END IF;
        UPDATE public.wallets
           SET available_balance = available_balance - v_usd_deduct,
               updated_at = NOW()
         WHERE id = v_wallet_id;
    END IF;

    INSERT INTO public.point_history (user_id, points, type, description, reference_id)
    VALUES (
        p_user_id,
        p_amount,
        'spend',
        p_description,
        p_reference_id
    );

    RETURN public.fn_get_effective_ksp(p_user_id)
        || jsonb_build_object(
            'success', true,
            'deducted', p_amount,
            'deducted_reward_ksp', v_from_reward,
            'deducted_wallet_ksp', v_from_wallet_ksp
        );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_deduct_effective_ksp(uuid, integer, text, text) TO authenticated;

-- ─── Lucky Wheel bundle purchase ────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.buy_spins_bundle(p_bundle_type text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_points_cost integer;
    v_spins_to_add integer;
    v_deduct jsonb;
    v_final_spins integer;
    v_balance jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    IF p_bundle_type = 'single' THEN
        v_points_cost := 100;
        v_spins_to_add := 1;
    ELSIF p_bundle_type = 'triple' THEN
        v_points_cost := 300;
        v_spins_to_add := 3;
    ELSIF p_bundle_type = 'septuple' THEN
        v_points_cost := 500;
        v_spins_to_add := 7;
    ELSE
        RETURN json_build_object('success', false, 'error', 'Invalid bundle type');
    END IF;

    v_deduct := public.fn_deduct_effective_ksp(
        v_user_id,
        v_points_cost,
        'Lucky Wheel bundle: ' || p_bundle_type,
        NULL
    );

    IF COALESCE((v_deduct->>'success')::boolean, false) IS NOT TRUE THEN
        RETURN json_build_object(
            'success', false,
            'error', COALESCE(v_deduct->>'error', 'Insufficient points')
        );
    END IF;

    UPDATE public.profiles
       SET stored_spins = COALESCE(stored_spins, 0) + v_spins_to_add,
           updated_at = NOW()
     WHERE id = v_user_id;

    SELECT stored_spins INTO v_final_spins FROM public.profiles WHERE id = v_user_id;
    v_balance := public.fn_get_effective_ksp(v_user_id);

    RETURN json_build_object(
        'success', true,
        'message', 'Bundle purchased successfully',
        'added_spins', v_spins_to_add,
        'stored_spins', v_final_spins,
        'new_balance', (v_balance->>'effective_ksp')::integer,
        'effective_ksp', (v_balance->>'effective_ksp')::integer,
        'reward_ksp', (v_balance->>'reward_ksp')::integer,
        'wallet_ksp', (v_balance->>'wallet_ksp')::integer
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.buy_spins_bundle(text) TO authenticated;

-- ─── Marketplace KSP checkout ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_marketplace_begin_checkout(
    p_idempotency_key text,
    p_payment_method text,
    p_subtotal numeric,
    p_discount numeric,
    p_total numeric,
    p_coupon_code text DEFAULT NULL,
    p_items jsonb DEFAULT '[]'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_order_id uuid;
  v_wallet_id uuid;
  v_available numeric(18, 4);
  v_running numeric(18, 4);
  v_tx_id uuid;
  v_ksp_cost int;
  v_frozen boolean;
  v_item jsonb;
  v_existing record;
  v_deduct jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_total <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid order total');
  END IF;

  IF p_payment_method NOT IN ('wallet', 'ksp') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid payment method');
  END IF;

  SELECT id, wallet_transaction_id, payment_status, status
    INTO v_existing
    FROM marketplace_orders
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;

  IF v_existing.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'order_id', v_existing.id,
      'transaction_id', v_existing.wallet_transaction_id,
      'idempotent', true,
      'payment_status', v_existing.payment_status,
      'status', v_existing.status
    );
  END IF;

  INSERT INTO marketplace_orders (
    user_id, idempotency_key, payment_method, payment_status,
    delivery_status, status, subtotal_amount, discount_amount,
    total_amount, coupon_code
  ) VALUES (
    v_user_id, p_idempotency_key, p_payment_method, 'pending',
    'pending', 'pending', p_subtotal, COALESCE(p_discount, 0),
    p_total, p_coupon_code
  ) RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO marketplace_order_items (
      order_id, variant_id, product_id, brand_id,
      variant_name_en, variant_name_ar, product_name_en, product_name_ar,
      brand_name_en, brand_name_ar, image_url, quantity, unit_price,
      discount_amount, total_price, provider_product_id, provider_sku
    ) VALUES (
      v_order_id,
      v_item->>'variant_id',
      v_item->>'product_id',
      v_item->>'brand_id',
      COALESCE(v_item->>'variant_name_en', ''),
      COALESCE(v_item->>'variant_name_ar', ''),
      COALESCE(v_item->>'product_name_en', ''),
      COALESCE(v_item->>'product_name_ar', ''),
      COALESCE(v_item->>'brand_name_en', ''),
      COALESCE(v_item->>'brand_name_ar', ''),
      COALESCE(v_item->>'image_url', ''),
      COALESCE((v_item->>'quantity')::int, 1),
      COALESCE((v_item->>'unit_price')::numeric, 0),
      COALESCE((v_item->>'discount_amount')::numeric, 0),
      COALESCE((v_item->>'total_price')::numeric, 0),
      NULLIF(v_item->>'provider_product_id', '')::bigint,
      v_item->>'provider_sku'
    );
  END LOOP;

  IF p_payment_method = 'wallet' THEN
    SELECT id, available_balance, is_frozen
      INTO v_wallet_id, v_available, v_frozen
      FROM wallets WHERE user_id = v_user_id AND currency = 'USD' FOR UPDATE;

    IF v_wallet_id IS NULL THEN
      UPDATE marketplace_orders SET status = 'failed', payment_status = 'failed', notes = 'Wallet not found'
        WHERE id = v_order_id;
      RETURN jsonb_build_object('success', false, 'error', 'Wallet not found', 'order_id', v_order_id);
    END IF;

    IF v_frozen THEN
      UPDATE marketplace_orders SET status = 'failed', payment_status = 'failed', notes = 'Wallet frozen'
        WHERE id = v_order_id;
      RETURN jsonb_build_object('success', false, 'error', 'Wallet is frozen', 'order_id', v_order_id);
    END IF;

    IF v_available < p_total THEN
      UPDATE marketplace_orders SET status = 'failed', payment_status = 'failed', notes = 'Insufficient balance'
        WHERE id = v_order_id;
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance', 'order_id', v_order_id);
    END IF;

    v_running := v_available - p_total;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      running_balance, description, idempotency_key, reference_id
    ) VALUES (
      v_user_id, v_wallet_id, 'marketplace_purchase', p_total, 0, 'USD', 'completed',
      v_running, 'Marketplace purchase', p_idempotency_key, v_order_id::text
    ) RETURNING id INTO v_tx_id;

    UPDATE wallets SET available_balance = v_running, updated_at = NOW() WHERE id = v_wallet_id;

  ELSE
    v_ksp_cost := CEIL(p_total)::int;

    v_deduct := public.fn_deduct_effective_ksp(
      v_user_id,
      v_ksp_cost,
      'Marketplace purchase (KSP)',
      v_order_id::text
    );

    IF COALESCE((v_deduct->>'success')::boolean, false) IS NOT TRUE THEN
      UPDATE marketplace_orders SET status = 'failed', payment_status = 'failed', notes = 'Insufficient KSP'
        WHERE id = v_order_id;
      RETURN jsonb_build_object(
        'success', false,
        'error', COALESCE(v_deduct->>'error', 'Insufficient KSP balance'),
        'order_id', v_order_id
      );
    END IF;

    v_tx_id := NULL;
  END IF;

  UPDATE marketplace_orders
    SET payment_status = 'paid',
        status = 'processing',
        delivery_status = 'processing',
        wallet_transaction_id = v_tx_id,
        timeline = jsonb_build_array(
          jsonb_build_object('status', 'pending', 'timestamp', now()),
          jsonb_build_object('status', 'processing', 'timestamp', now(), 'note', 'Payment captured')
        )
    WHERE id = v_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'transaction_id', v_tx_id,
    'idempotent', false,
    'payment_status', 'paid',
    'status', 'processing',
    'effective_ksp', (public.fn_get_effective_ksp(v_user_id)->>'effective_ksp')::int
  );
END;
$$;

-- ─── KSP P2P transfer (deduct effective, credit reward to receiver) ───────────

CREATE OR REPLACE FUNCTION public.fn_transfer_ksp(
    p_amount integer,
    p_receiver_referral_code text,
    p_idempotency_key text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_sender_id uuid := auth.uid();
    v_receiver_id uuid;
    v_receiver_name text;
    v_sender_name text;
    v_deduct jsonb;
    v_tx_id uuid;
BEGIN
    IF v_sender_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    IF p_amount <= 0 THEN
        RETURN json_build_object('success', false, 'error', 'Invalid amount');
    END IF;

    SELECT id, full_name INTO v_receiver_id, v_receiver_name
    FROM profiles
    WHERE UPPER(referral_code) = UPPER(REPLACE(p_receiver_referral_code, '-', ''))
    LIMIT 1;

    IF v_receiver_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Receiver not found');
    END IF;

    IF v_receiver_id = v_sender_id THEN
        RETURN json_build_object('success', false, 'error', 'Cannot transfer to yourself');
    END IF;

    SELECT full_name INTO v_sender_name FROM profiles WHERE id = v_sender_id;

    v_deduct := public.fn_deduct_effective_ksp(
        v_sender_id,
        p_amount,
        'KSP transfer to ' || COALESCE(v_receiver_name, 'user'),
        p_idempotency_key
    );

    IF COALESCE((v_deduct->>'success')::boolean, false) IS NOT TRUE THEN
        RETURN json_build_object(
            'success', false,
            'error', COALESCE(v_deduct->>'error', 'Insufficient points')
        );
    END IF;

    PERFORM public.fn_credit_reward_ksp(
        v_receiver_id,
        p_amount,
        'KSP transfer from ' || COALESCE(v_sender_name, 'user'),
        p_idempotency_key
    );

    SELECT gen_random_uuid() INTO v_tx_id;

    PERFORM public.fn_create_notification(
        v_receiver_id,
        'تم استلام نقاط',
        'تم تحويل ' || p_amount::text || ' KSP إليك',
        'transfer_received', 'transaction', v_tx_id::text, '/wallet', 'user', 'normal'
    );

    PERFORM public.fn_create_notification(
        v_sender_id,
        'تم إرسال النقاط',
        'تم تحويل ' || p_amount::text || ' KSP إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
        'transfer_sent', 'transaction', v_tx_id::text, '/wallet', 'user', 'normal'
    );

    RETURN json_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'receiver_name', v_receiver_name,
        'message', 'Transfer successful',
        'effective_ksp', (public.fn_get_effective_ksp(v_sender_id)->>'effective_ksp')::int
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_transfer_ksp(integer, text, text) TO authenticated;

-- ─── spin_wheel: return effective KSP after reward ───────────────────────────

CREATE OR REPLACE FUNCTION public.spin_wheel()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_user_profile RECORD;
    v_reward_profile RECORD;
    v_selected RECORD;
    v_spin_type text;
    v_total_weight integer;
    v_random_num integer;
    v_cumulative_weight integer := 0;
    v_last_spin_at timestamptz;
    v_reward_json jsonb;
    v_balance jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'profile_not_found');
    END IF;

    IF v_user_profile.status IN ('blocked', 'suspended') THEN
        RETURN json_build_object('success', false, 'error', 'account_restricted');
    END IF;

    SELECT * INTO v_reward_profile FROM public.get_active_spin_wheel_profile();
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'no_active_reward_profile');
    END IF;

    SELECT created_at INTO v_last_spin_at
    FROM public.spin_history
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_spin_at IS NOT NULL AND v_last_spin_at > NOW() - INTERVAL '3 seconds' THEN
        RETURN json_build_object('success', false, 'error', 'spin_too_fast');
    END IF;

    IF v_user_profile.last_free_spin_at IS NULL
       OR v_user_profile.last_free_spin_at < NOW() - INTERVAL '24 hours' THEN
        v_spin_type := 'free';
        UPDATE public.profiles
        SET last_free_spin_at = NOW(), updated_at = NOW()
        WHERE id = v_user_id;
    ELSIF COALESCE(v_user_profile.stored_spins, 0) > 0 THEN
        v_spin_type := 'stored';
        UPDATE public.profiles
        SET stored_spins = stored_spins - 1, updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        RETURN json_build_object('success', false, 'error', 'no_spins_available');
    END IF;

    SELECT COALESCE(SUM(pw.weight), 0) INTO v_total_weight
    FROM public.spin_wheel_profile_weights pw
    JOIN public.spin_wheel_rewards r ON r.id = pw.reward_id
    WHERE pw.profile_id = v_reward_profile.id
      AND r.is_active = true;

    IF v_total_weight <= 0 THEN
        RETURN json_build_object('success', false, 'error', 'no_active_rewards');
    END IF;

    v_random_num := floor(random() * v_total_weight)::integer + 1;

    FOR v_selected IN
        SELECT r.*, pw.weight AS profile_weight
        FROM public.spin_wheel_rewards r
        JOIN public.spin_wheel_profile_weights pw ON pw.reward_id = r.id
        WHERE pw.profile_id = v_reward_profile.id
          AND r.is_active = true
        ORDER BY r.display_order, r.id
    LOOP
        v_cumulative_weight := v_cumulative_weight + v_selected.profile_weight;
        IF v_random_num <= v_cumulative_weight THEN
            EXIT;
        END IF;
    END LOOP;

    IF v_selected.id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'reward_selection_failed');
    END IF;

    IF v_selected.points > 0 THEN
        PERFORM public.fn_credit_reward_ksp(
            v_user_id,
            v_selected.points,
            'Spin Wheel Reward: ' || v_selected.label,
            v_selected.id::text
        );
    END IF;

    v_reward_json := row_to_json(v_selected)::jsonb
        || jsonb_build_object(
            'profile_id', v_reward_profile.id,
            'profile_slug', v_reward_profile.slug,
            'profile_name', v_reward_profile.name,
            'profile_weight', v_selected.profile_weight
        );

    INSERT INTO public.spin_history (
        user_id, reward_id, reward_json, spin_type,
        profile_id, profile_slug, profile_name, profile_weight
    ) VALUES (
        v_user_id,
        v_selected.id,
        v_reward_json,
        v_spin_type,
        v_reward_profile.id,
        v_reward_profile.slug,
        v_reward_profile.name,
        v_selected.profile_weight
    );

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        v_user_id,
        'user',
        'spin_reward_granted',
        'spin_wheel_reward',
        v_selected.id::text,
        jsonb_build_object(
            'label', v_selected.label,
            'points', v_selected.points,
            'spin_type', v_spin_type,
            'profile_slug', v_reward_profile.slug,
            'profile_name', v_reward_profile.name,
            'profile_weight', v_selected.profile_weight
        ),
        CASE WHEN v_selected.points >= 200 THEN 'warning' ELSE 'info' END
    );

    v_balance := public.fn_get_effective_ksp(v_user_id);

    RETURN json_build_object(
        'success', true,
        'reward', json_build_object(
            'id', v_selected.id,
            'label', v_selected.label,
            'points', v_selected.points,
            'icon', v_selected.icon,
            'color', v_selected.color
        ),
        'profile', json_build_object(
            'id', v_reward_profile.id,
            'slug', v_reward_profile.slug,
            'name', v_reward_profile.name
        ),
        'spin_type', v_spin_type,
        'new_balance', (v_balance->>'effective_ksp')::integer,
        'effective_ksp', (v_balance->>'effective_ksp')::integer,
        'reward_ksp', (v_balance->>'reward_ksp')::integer,
        'wallet_ksp', (v_balance->>'wallet_ksp')::integer,
        'stored_spins', (SELECT stored_spins FROM public.profiles WHERE id = v_user_id)
    );
END;
$$;
