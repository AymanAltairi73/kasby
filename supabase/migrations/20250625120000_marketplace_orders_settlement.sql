-- Marketplace orders, settlement RPCs, and provider health metrics.
-- Apply via: supabase db push  OR  supabase migration up

-- ── Extend transaction types ──────────────────────────────────────────────
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;
ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check CHECK (
  type = ANY (ARRAY[
    'deposit', 'withdrawal', 'transfer_in', 'transfer_out', 'investment',
    'investment_return', 'loan_disbursement', 'loan_repayment', 'reward',
    'adjustment', 'profit', 'fee', 'admin_credit', 'admin_debit',
    'collateral_lock', 'collateral_release', 'reversal', 'compensation',
    'marketplace_purchase', 'marketplace_refund'
  ])
);

-- ── Orders ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_orders (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  idempotency_key TEXT NOT NULL,
  provider_name TEXT NOT NULL DEFAULT 'reloadly',
  provider_transaction_id BIGINT,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('wallet', 'ksp')),
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    payment_status IN ('pending', 'paid', 'refunded', 'failed')
  ),
  delivery_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    delivery_status IN (
      'pending', 'processing', 'delivered', 'completed', 'failed', 'cancelled'
    )
  ),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (
    status IN (
      'pending', 'processing', 'providerAccepted', 'delivered', 'completed',
      'failed', 'cancelled', 'refundRequested', 'refunded'
    )
  ),
  subtotal_amount NUMERIC(18, 4) NOT NULL CHECK (subtotal_amount >= 0),
  discount_amount NUMERIC(18, 4) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
  total_amount NUMERIC(18, 4) NOT NULL CHECK (total_amount >= 0),
  coupon_code TEXT,
  wallet_transaction_id UUID REFERENCES public.transactions(id),
  delivery_code TEXT,
  delivery_info TEXT,
  timeline JSONB NOT NULL DEFAULT '[]'::jsonb,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT marketplace_orders_idempotency_unique UNIQUE (idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_user_created
  ON public.marketplace_orders (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_status
  ON public.marketplace_orders (user_id, status);

-- ── Order items ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_order_items (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES public.marketplace_orders(id) ON DELETE CASCADE,
  variant_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  brand_id TEXT NOT NULL,
  variant_name_en TEXT NOT NULL,
  variant_name_ar TEXT NOT NULL,
  product_name_en TEXT NOT NULL,
  product_name_ar TEXT NOT NULL,
  brand_name_en TEXT NOT NULL,
  brand_name_ar TEXT NOT NULL,
  image_url TEXT DEFAULT '',
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(18, 4) NOT NULL CHECK (unit_price >= 0),
  discount_amount NUMERIC(18, 4) NOT NULL DEFAULT 0,
  total_price NUMERIC(18, 4) NOT NULL CHECK (total_price >= 0),
  provider_product_id BIGINT,
  provider_sku TEXT,
  provider_transaction_id BIGINT,
  redeem_codes JSONB NOT NULL DEFAULT '[]'::jsonb,
  fulfillment_status TEXT NOT NULL DEFAULT 'pending' CHECK (
    fulfillment_status IN ('pending', 'processing', 'delivered', 'failed')
  ),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_order_items_order
  ON public.marketplace_order_items (order_id);

-- ── Provider health / API metrics ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_provider_health (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  provider_name TEXT NOT NULL DEFAULT 'reloadly',
  environment TEXT NOT NULL DEFAULT 'sandbox',
  oauth_status TEXT NOT NULL DEFAULT 'unknown',
  api_latency_ms INT,
  catalog_count INT,
  balance_amount NUMERIC(18, 4),
  balance_currency TEXT,
  failed_requests INT NOT NULL DEFAULT 0,
  checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_marketplace_provider_health_checked
  ON public.marketplace_provider_health (provider_name, checked_at DESC);

CREATE TABLE IF NOT EXISTS public.marketplace_api_request_log (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  provider_name TEXT NOT NULL DEFAULT 'reloadly',
  action TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT false,
  status_code INT,
  latency_ms INT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_api_request_log_created
  ON public.marketplace_api_request_log (provider_name, created_at DESC);

-- ── RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_provider_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_api_request_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS marketplace_orders_select_own ON public.marketplace_orders;
CREATE POLICY marketplace_orders_select_own ON public.marketplace_orders
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS marketplace_order_items_select_own ON public.marketplace_order_items;
CREATE POLICY marketplace_order_items_select_own ON public.marketplace_order_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.marketplace_orders o
      WHERE o.id = marketplace_order_items.order_id AND o.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS marketplace_provider_health_select ON public.marketplace_provider_health;
CREATE POLICY marketplace_provider_health_select ON public.marketplace_provider_health
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS marketplace_api_request_log_select ON public.marketplace_api_request_log;
CREATE POLICY marketplace_api_request_log_select ON public.marketplace_api_request_log
  FOR SELECT TO authenticated
  USING (true);

-- ── Helper: touch updated_at ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_touch_order()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_marketplace_orders_updated ON public.marketplace_orders;
CREATE TRIGGER trg_marketplace_orders_updated
  BEFORE UPDATE ON public.marketplace_orders
  FOR EACH ROW EXECUTE FUNCTION public.fn_marketplace_touch_order();

-- ── RPC: begin checkout (reserve payment + create order) ─────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_begin_checkout(
  p_idempotency_key TEXT,
  p_payment_method TEXT,
  p_subtotal NUMERIC,
  p_discount NUMERIC,
  p_total NUMERIC,
  p_coupon_code TEXT DEFAULT NULL,
  p_items JSONB DEFAULT '[]'::jsonb
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_order_id UUID;
  v_wallet_id UUID;
  v_available NUMERIC(18, 4);
  v_running NUMERIC(18, 4);
  v_tx_id UUID;
  v_points INT;
  v_ksp_cost INT;
  v_frozen BOOLEAN;
  v_item JSONB;
  v_existing RECORD;
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

  -- Idempotency: return existing order
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

  -- Create pending order shell
  INSERT INTO marketplace_orders (
    user_id, idempotency_key, payment_method, payment_status,
    delivery_status, status, subtotal_amount, discount_amount,
    total_amount, coupon_code
  ) VALUES (
    v_user_id, p_idempotency_key, p_payment_method, 'pending',
    'pending', 'pending', p_subtotal, COALESCE(p_discount, 0),
    p_total, p_coupon_code
  ) RETURNING id INTO v_order_id;

  -- Insert line items
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
      COALESCE((v_item->>'quantity')::INT, 1),
      COALESCE((v_item->>'unit_price')::NUMERIC, 0),
      COALESCE((v_item->>'discount_amount')::NUMERIC, 0),
      COALESCE((v_item->>'total_price')::NUMERIC, 0),
      NULLIF(v_item->>'provider_product_id', '')::BIGINT,
      v_item->>'provider_sku'
    );
  END LOOP;

  -- Settle payment
  IF p_payment_method = 'wallet' THEN
    SELECT id, available_balance, is_frozen
      INTO v_wallet_id, v_available, v_frozen
      FROM wallets WHERE user_id = v_user_id FOR UPDATE;

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
      v_running, 'Marketplace purchase', p_idempotency_key, v_order_id::TEXT
    ) RETURNING id INTO v_tx_id;

    UPDATE wallets SET available_balance = v_running WHERE id = v_wallet_id;

  ELSE
    v_ksp_cost := CEIL(p_total)::INT;

    PERFORM ensure_user_points(v_user_id);

    SELECT current_balance INTO v_points
      FROM user_points WHERE user_id = v_user_id FOR UPDATE;

    IF v_points IS NULL OR v_points < v_ksp_cost THEN
      UPDATE marketplace_orders SET status = 'failed', payment_status = 'failed', notes = 'Insufficient KSP'
        WHERE id = v_order_id;
      RETURN jsonb_build_object('success', false, 'error', 'Insufficient KSP balance', 'order_id', v_order_id);
    END IF;

    UPDATE user_points
      SET current_balance = current_balance - v_ksp_cost,
          total_spent = total_spent + v_ksp_cost,
          updated_at = now()
      WHERE user_id = v_user_id;

    INSERT INTO point_history (user_id, points, type, description, reference_id)
    VALUES (v_user_id, -v_ksp_cost, 'spend', 'Marketplace purchase (KSP)', v_order_id::TEXT);

    -- Wallet tx id null for KSP; reference stored on order notes
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
    'status', 'processing'
  );
END;
$$;

-- ── RPC: complete order after provider fulfillment ────────────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_complete_order(
  p_order_id UUID,
  p_provider_transaction_id BIGINT DEFAULT NULL,
  p_delivery_code TEXT DEFAULT NULL,
  p_delivery_info TEXT DEFAULT NULL,
  p_item_updates JSONB DEFAULT '[]'::jsonb
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_order RECORD;
  v_item JSONB;
  v_item_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_order FROM marketplace_orders
    WHERE id = p_order_id AND user_id = v_user_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  IF v_order.payment_status <> 'paid' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order payment not settled');
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_item_updates)
  LOOP
    v_item_id := (v_item->>'item_id')::UUID;
    UPDATE marketplace_order_items SET
      provider_transaction_id = COALESCE((v_item->>'provider_transaction_id')::BIGINT, provider_transaction_id),
      redeem_codes = COALESCE(v_item->'redeem_codes', redeem_codes),
      fulfillment_status = COALESCE(v_item->>'fulfillment_status', 'delivered')
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;

  UPDATE marketplace_orders SET
    provider_transaction_id = COALESCE(p_provider_transaction_id, provider_transaction_id),
    delivery_code = COALESCE(p_delivery_code, delivery_code),
    delivery_info = COALESCE(p_delivery_info, delivery_info),
    delivery_status = 'completed',
    status = 'completed',
    timeline = timeline || jsonb_build_array(
      jsonb_build_object('status', 'delivered', 'timestamp', now()),
      jsonb_build_object('status', 'completed', 'timestamp', now())
    )
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id, 'status', 'completed');
END;
$$;

-- ── RPC: refund on provider failure ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_refund_order(
  p_order_id UUID,
  p_reason TEXT DEFAULT 'Provider fulfillment failed'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_order RECORD;
  v_wallet_id UUID;
  v_available NUMERIC(18, 4);
  v_refund_tx UUID;
  v_ksp_cost INT;
  v_points INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_order FROM marketplace_orders
    WHERE id = p_order_id AND user_id = v_user_id FOR UPDATE;

  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  IF v_order.payment_status = 'refunded' THEN
    RETURN jsonb_build_object('success', true, 'order_id', p_order_id, 'already_refunded', true);
  END IF;

  IF v_order.payment_status <> 'paid' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Nothing to refund');
  END IF;

  IF v_order.payment_method = 'wallet' THEN
    SELECT id, available_balance INTO v_wallet_id, v_available
      FROM wallets WHERE user_id = v_user_id FOR UPDATE;

    v_available := v_available + v_order.total_amount;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      running_balance, description, idempotency_key, reference_id
    ) VALUES (
      v_user_id, v_wallet_id, 'marketplace_refund', v_order.total_amount, 0, 'USD', 'completed',
      v_available, 'Marketplace refund: ' || p_reason,
      v_order.idempotency_key || '_refund', p_order_id::TEXT
    ) RETURNING id INTO v_refund_tx;

    UPDATE wallets SET available_balance = v_available WHERE id = v_wallet_id;

  ELSE
    v_ksp_cost := CEIL(v_order.total_amount)::INT;
    PERFORM ensure_user_points(v_user_id);

    UPDATE user_points
      SET current_balance = current_balance + v_ksp_cost,
          total_spent = GREATEST(total_spent - v_ksp_cost, 0),
          updated_at = now()
      WHERE user_id = v_user_id;

    INSERT INTO point_history (user_id, points, type, description, reference_id)
    VALUES (v_user_id, v_ksp_cost, 'earn', 'Marketplace refund (KSP): ' || p_reason, p_order_id::TEXT);
  END IF;

  UPDATE marketplace_order_items SET fulfillment_status = 'failed'
    WHERE order_id = p_order_id AND fulfillment_status <> 'delivered';

  UPDATE marketplace_orders SET
    payment_status = 'refunded',
    status = 'refunded',
    delivery_status = 'failed',
    notes = p_reason,
    timeline = timeline || jsonb_build_array(
      jsonb_build_object('status', 'failed', 'timestamp', now(), 'note', p_reason),
      jsonb_build_object('status', 'refunded', 'timestamp', now())
    )
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id, 'refund_transaction_id', v_refund_tx);
END;
$$;

-- ── RPC: record provider health snapshot ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_record_health(
  p_provider_name TEXT,
  p_environment TEXT,
  p_oauth_status TEXT,
  p_api_latency_ms INT,
  p_catalog_count INT,
  p_balance_amount NUMERIC,
  p_balance_currency TEXT,
  p_failed_requests INT,
  p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id UUID;
BEGIN
  INSERT INTO marketplace_provider_health (
    provider_name, environment, oauth_status, api_latency_ms,
    catalog_count, balance_amount, balance_currency, failed_requests, metadata
  ) VALUES (
    p_provider_name, p_environment, p_oauth_status, p_api_latency_ms,
    p_catalog_count, p_balance_amount, p_balance_currency, p_failed_requests, p_metadata
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- ── RPC: log API request ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_log_api_request(
  p_provider_name TEXT,
  p_action TEXT,
  p_success BOOLEAN,
  p_status_code INT DEFAULT NULL,
  p_latency_ms INT DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO marketplace_api_request_log (
    provider_name, action, success, status_code, latency_ms, error_message
  ) VALUES (
    p_provider_name, p_action, p_success, p_status_code, p_latency_ms, p_error_message
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_marketplace_begin_checkout TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_marketplace_complete_order TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_marketplace_refund_order TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_marketplace_record_health TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_marketplace_log_api_request TO authenticated, service_role;
