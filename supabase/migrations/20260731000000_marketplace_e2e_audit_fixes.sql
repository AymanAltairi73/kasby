-- Marketplace end-to-end audit fixes:
-- - restore strict RLS after local marketplace rebuild
-- - add idempotency and notifications to digital-code purchases
-- - expose marketplace tables through Supabase Realtime

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

ALTER TABLE public.marketplace_orders
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
  ADD COLUMN IF NOT EXISTS wallet_transaction_id UUID REFERENCES public.transactions(id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_marketplace_orders_idempotency_key
  ON public.marketplace_orders (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_marketplace_digital_codes_order_id
  ON public.marketplace_digital_codes (order_id)
  WHERE order_id IS NOT NULL;

-- The routed user store is the local digital-code marketplace. Recreate this
-- table because an older TopUp checkout path still joins it when enabled.
CREATE TABLE IF NOT EXISTS public.marketplace_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.marketplace_orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.marketplace_products(id) ON DELETE SET NULL,
  product_name_ar TEXT NOT NULL DEFAULT '',
  product_name_en TEXT NOT NULL DEFAULT '',
  image_url TEXT,
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price NUMERIC(18, 4) NOT NULL DEFAULT 0,
  total_price NUMERIC(18, 4) NOT NULL DEFAULT 0,
  delivery_code TEXT,
  serial_number TEXT,
  fulfillment_status TEXT NOT NULL DEFAULT 'delivered',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.marketplace_order_items ENABLE ROW LEVEL SECURITY;

-- Notification types used by marketplace purchase flow.
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IS NULL OR type = ANY (ARRAY[
      'deposit_submitted','deposit_approved','deposit_rejected',
      'withdrawal_requested','withdrawal_approved','withdrawal_rejected','withdrawal_completed',
      'transfer_received','transfer_sent',
      'loan_requested','loan_approved','loan_rejected','loan_repayment_due','loan_overdue','loan_paid',
      'investment_created','daily_profit','investment_matured','investment_cancelled',
      'marketplace_purchase','marketplace_refund','store_purchase',
      'chat_new_message','chat_admin_reply','chat_resolved','chat_escalated',
      'kyc_approved','kyc_rejected',
      'account_flagged','account_frozen','account_blocked','account_reactivated','account_deleted','account_unblocked',
      'permission_withdrawal_granted','permission_transfer_granted','permission_qr_receive_granted',
      'role_upgraded','profile_updated','commission_earned',
      'referral_bonus',
      'agent_deposit_pending','agent_withdrawal_pending','agent_role_change',
      'admin_kyc_pending','admin_withdrawal_pending','admin_deposit_pending','admin_flagged_user','admin_new_chat','admin_user_deleted',
      'social_friend_request','social_friend_accepted','social_chat',
      'system','maintenance','announcement','security_alert','info','success','warning','critical','reward','notification',
      'wheel_reminder','checkin_reminder'
    ]::TEXT[])
  );

-- Replace broad "authenticated users can do everything" marketplace policies.
DROP POLICY IF EXISTS public_categories_read ON public.marketplace_categories;
DROP POLICY IF EXISTS public_products_read ON public.marketplace_products;
DROP POLICY IF EXISTS public_banners_read ON public.marketplace_banners;
DROP POLICY IF EXISTS user_orders_own ON public.marketplace_orders;
DROP POLICY IF EXISTS admin_all_categories ON public.marketplace_categories;
DROP POLICY IF EXISTS admin_all_products ON public.marketplace_products;
DROP POLICY IF EXISTS admin_all_codes ON public.marketplace_digital_codes;
DROP POLICY IF EXISTS admin_all_banners ON public.marketplace_banners;
DROP POLICY IF EXISTS admin_all_orders ON public.marketplace_orders;
DROP POLICY IF EXISTS user_order_items_own ON public.marketplace_order_items;
DROP POLICY IF EXISTS admin_all_order_items ON public.marketplace_order_items;

CREATE POLICY public_categories_read ON public.marketplace_categories
  FOR SELECT TO authenticated
  USING (is_active = TRUE OR public.is_admin());

CREATE POLICY public_products_read ON public.marketplace_products
  FOR SELECT TO authenticated
  USING (is_active = TRUE OR public.is_admin());

CREATE POLICY public_banners_read ON public.marketplace_banners
  FOR SELECT TO authenticated
  USING (is_active = TRUE OR public.is_admin());

CREATE POLICY admin_all_categories ON public.marketplace_categories
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY admin_all_products ON public.marketplace_products
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY admin_all_codes ON public.marketplace_digital_codes
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY admin_all_banners ON public.marketplace_banners
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY user_orders_select_own ON public.marketplace_orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY admin_all_orders ON public.marketplace_orders
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY user_order_items_own ON public.marketplace_order_items
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.marketplace_orders o
      WHERE o.id = marketplace_order_items.order_id
        AND o.user_id = auth.uid()
    )
  );

CREATE POLICY admin_all_order_items ON public.marketplace_order_items
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.fn_marketplace_buy_product(
  p_product_id UUID,
  p_payment_method TEXT,
  p_idempotency_key TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_product RECORD;
  v_code_rec RECORD;
  v_wallet_id UUID;
  v_avail_bal NUMERIC(18, 4);
  v_frozen BOOLEAN;
  v_new_bal NUMERIC(18, 4);
  v_order_id UUID := gen_random_uuid();
  v_order_num TEXT;
  v_paid_amount NUMERIC(12, 2);
  v_tx_id UUID;
  v_ksp_cost INTEGER;
  v_existing RECORD;
  v_deduct JSONB;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message_ar', 'Login is required');
  END IF;

  IF p_payment_method NOT IN ('wallet', 'ksp') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_method', 'message_ar', 'Invalid payment method');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id, order_number, delivery_code, serial_number, amount, payment_method
      INTO v_existing
      FROM public.marketplace_orders
      WHERE user_id = v_user_id
        AND idempotency_key = p_idempotency_key
      LIMIT 1;

    IF v_existing.id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'idempotent', true,
        'order_id', v_existing.id,
        'order_number', v_existing.order_number,
        'delivery_code', v_existing.delivery_code,
        'serial_number', v_existing.serial_number,
        'paid_amount', v_existing.amount,
        'payment_method', v_existing.payment_method
      );
    END IF;
  END IF;

  SELECT *
    INTO v_product
    FROM public.marketplace_products
    WHERE id = p_product_id AND is_active = TRUE
    FOR SHARE;

  IF v_product.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'product_not_found', 'message_ar', 'Product is unavailable');
  END IF;

  SELECT id, code, serial_number
    INTO v_code_rec
    FROM public.marketplace_digital_codes
    WHERE product_id = p_product_id
      AND is_used = FALSE
    ORDER BY created_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED;

  IF v_code_rec.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'out_of_stock', 'message_ar', 'This product is out of stock');
  END IF;

  IF p_payment_method = 'wallet' THEN
    SELECT id, available_balance, is_frozen
      INTO v_wallet_id, v_avail_bal, v_frozen
      FROM public.wallets
      WHERE user_id = v_user_id
        AND COALESCE(currency, 'USD') = 'USD'
      FOR UPDATE;

    IF v_wallet_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found', 'message_ar', 'Wallet not found');
    END IF;

    IF COALESCE(v_frozen, FALSE) THEN
      RETURN jsonb_build_object('success', false, 'error', 'wallet_frozen', 'message_ar', 'Wallet is frozen');
    END IF;

    IF v_avail_bal < v_product.wallet_price THEN
      RETURN jsonb_build_object('success', false, 'error', 'insufficient_wallet_balance', 'message_ar', 'Insufficient wallet balance');
    END IF;

    v_new_bal := v_avail_bal - v_product.wallet_price;
    UPDATE public.wallets
      SET available_balance = v_new_bal, updated_at = NOW()
      WHERE id = v_wallet_id;

    INSERT INTO public.transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      running_balance, description, idempotency_key, reference_id
    ) VALUES (
      v_user_id, v_wallet_id, 'marketplace_purchase', v_product.wallet_price, 0, 'USD', 'completed',
      v_new_bal, 'Marketplace purchase: ' || v_product.name_en, p_idempotency_key, v_order_id::TEXT
    )
    RETURNING id INTO v_tx_id;

    v_paid_amount := v_product.wallet_price;
  ELSE
    IF v_product.ksp_price IS NULL OR v_product.ksp_price <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'ksp_not_supported', 'message_ar', 'KSP payment is not available for this product');
    END IF;

    v_ksp_cost := CEIL(v_product.ksp_price)::INTEGER;
    v_deduct := public.fn_deduct_effective_ksp(
      v_user_id,
      v_ksp_cost,
      'Marketplace purchase: ' || v_product.name_en,
      v_order_id::TEXT
    );

    IF COALESCE((v_deduct->>'success')::BOOLEAN, FALSE) IS NOT TRUE THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', COALESCE(v_deduct->>'error', 'insufficient_ksp_balance'),
        'message_ar', 'Insufficient KSP balance'
      );
    END IF;

    v_paid_amount := v_ksp_cost;
  END IF;

  v_order_num := 'KSB-' || TO_CHAR(NOW(), 'YYMMDD') || '-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 6));

  INSERT INTO public.marketplace_orders (
    id, order_number, user_id, product_id, product_name_ar, product_name_en,
    product_image_url, amount, payment_method, status, delivery_code, serial_number,
    idempotency_key, wallet_transaction_id
  ) VALUES (
    v_order_id, v_order_num, v_user_id, p_product_id, v_product.name_ar, v_product.name_en,
    v_product.image_url, v_paid_amount, p_payment_method, 'completed', v_code_rec.code, v_code_rec.serial_number,
    p_idempotency_key, v_tx_id
  );

  INSERT INTO public.marketplace_order_items (
    order_id, product_id, product_name_ar, product_name_en, image_url,
    quantity, unit_price, total_price, delivery_code, serial_number
  ) VALUES (
    v_order_id, p_product_id, v_product.name_ar, v_product.name_en, v_product.image_url,
    1, v_paid_amount, v_paid_amount, v_code_rec.code, v_code_rec.serial_number
  );

  UPDATE public.marketplace_digital_codes
    SET is_used = TRUE,
        used_by_user_id = v_user_id,
        used_at = NOW(),
        order_id = v_order_id
    WHERE id = v_code_rec.id
      AND is_used = FALSE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Selected digital code was already consumed';
  END IF;

  PERFORM public.fn_create_notification(
    v_user_id,
    'Store purchase completed',
    'Your digital code for ' || v_product.name_en || ' is ready.',
    'marketplace_purchase',
    'marketplace_order',
    v_order_id::TEXT,
    '/store-orders',
    'user',
    'normal'
  );

  RETURN jsonb_build_object(
    'success', true,
    'idempotent', false,
    'order_id', v_order_id,
    'order_number', v_order_num,
    'delivery_code', v_code_rec.code,
    'serial_number', v_code_rec.serial_number,
    'paid_amount', v_paid_amount,
    'payment_method', p_payment_method
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_marketplace_buy_product(UUID, TEXT, TEXT) TO authenticated;

DO $$
DECLARE
  v_table TEXT;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'marketplace_categories',
    'marketplace_products',
    'marketplace_banners',
    'marketplace_orders',
    'marketplace_order_items',
    'marketplace_digital_codes'
  ]
  LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = v_table
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', v_table);
    END IF;
  END LOOP;
END $$;
