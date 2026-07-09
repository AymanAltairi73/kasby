-- Fix integer overflow in fn_get_effective_ksp / fn_deduct_effective_ksp
-- Large USD wallets (FLOOR(usd * 1000) > 2^31-1) caused registration rewards and KSP reads to fail.

CREATE OR REPLACE FUNCTION public.fn_get_effective_ksp(p_user_id uuid DEFAULT auth.uid())
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_wallet_usd numeric(18, 4) := 0;
    v_reward_ksp bigint := 0;
    v_wallet_ksp bigint := 0;
    v_effective_ksp bigint := 0;
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

    SELECT COALESCE(up.current_balance, 0)::bigint
      INTO v_reward_ksp
      FROM public.user_points up
     WHERE up.user_id = p_user_id;

    v_wallet_ksp := FLOOR(v_wallet_usd * 1000)::bigint;
    v_effective_ksp := v_wallet_ksp + v_reward_ksp;

    RETURN jsonb_build_object(
        'success', true,
        'wallet_usd', v_wallet_usd,
        'wallet_ksp', v_wallet_ksp,
        'reward_ksp', v_reward_ksp,
        'effective_ksp', v_effective_ksp
    );
END;
$$;

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
    v_reward_ksp bigint := 0;
    v_wallet_ksp bigint := 0;
    v_effective bigint := 0;
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

    SELECT COALESCE(up.current_balance, 0)::bigint
      INTO v_reward_ksp
      FROM public.user_points up
     WHERE up.user_id = p_user_id
       FOR UPDATE;

    v_wallet_ksp := FLOOR(v_wallet_usd * 1000)::bigint;
    v_effective := v_wallet_ksp + v_reward_ksp;

    IF v_effective < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient points');
    END IF;

    v_from_reward := LEAST(v_reward_ksp::integer, p_amount);
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

-- Backfill registration rewards for referred users missing payout (run manually after deploy if needed):
-- SELECT process_registration_rewards(user_id, referrer_id) FROM profiles p
-- WHERE p.referred_by IS NOT NULL AND NOT EXISTS (
--   SELECT 1 FROM referral_registration_rewards rr WHERE rr.user_id = p.id
-- );
