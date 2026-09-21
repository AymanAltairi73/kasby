-- Migration: Store TopUp.dev Integration support
-- Adds provider_order_id column and updates complete order function.

-- 1. Ensure all required columns exist on marketplace_orders
ALTER TABLE public.marketplace_orders ADD COLUMN IF NOT EXISTS idempotency_key TEXT;
ALTER TABLE public.marketplace_orders ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending';
ALTER TABLE public.marketplace_orders ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'pending';
ALTER TABLE public.marketplace_orders ADD COLUMN IF NOT EXISTS wallet_transaction_id UUID REFERENCES public.transactions(id);
ALTER TABLE public.marketplace_orders ADD COLUMN IF NOT EXISTS provider_transaction_id BIGINT;
ALTER TABLE public.marketplace_orders ADD COLUMN IF NOT EXISTS provider_order_id TEXT;
ALTER TABLE public.marketplace_orders ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.marketplace_orders ALTER COLUMN order_number DROP NOT NULL;
ALTER TABLE public.marketplace_orders ALTER COLUMN order_number SET DEFAULT ('ORD-' || substr(md5(random()::text), 1, 10));

CREATE UNIQUE INDEX IF NOT EXISTS idx_marketplace_orders_idempotency_unique ON public.marketplace_orders (idempotency_key);

-- 2. Ensure all required columns exist on marketplace_order_items
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS variant_name_en TEXT DEFAULT '';
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS variant_name_ar TEXT DEFAULT '';
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS product_name_en TEXT DEFAULT '';
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS product_name_ar TEXT DEFAULT '';
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS brand_name_en TEXT DEFAULT '';
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS brand_name_ar TEXT DEFAULT '';
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT '';
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS unit_price NUMERIC(18, 4) DEFAULT 0;
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(18, 4) DEFAULT 0;
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS total_price NUMERIC(18, 4) DEFAULT 0;
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS provider_product_id BIGINT;
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS provider_sku TEXT;
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS provider_transaction_id BIGINT;
ALTER TABLE public.marketplace_order_items ADD COLUMN IF NOT EXISTS redeem_codes JSONB DEFAULT '[]'::jsonb;
-- Convert enum column types to text if they exist as enums to prevent PostgreSQL type cast errors
DO $$ BEGIN
  ALTER TABLE public.marketplace_orders ALTER COLUMN payment_method TYPE TEXT USING payment_method::text;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.marketplace_orders ALTER COLUMN status TYPE TEXT USING status::text;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 3. Re-define fn_marketplace_begin_checkout with explicit text casting
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
    order_number, user_id, idempotency_key, payment_method, payment_status,
    delivery_status, status, subtotal_amount, discount_amount,
    total_amount, coupon_code
  ) VALUES (
    'ORD-' || UPPER(SUBSTRING(p_idempotency_key FROM 1 FOR 8)),
    v_user_id, p_idempotency_key, p_payment_method::text, 'pending',
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
    'status', 'processing'
  );
END;
$$;

-- 2. Update fn_marketplace_complete_order to accept and save provider_order_id
DROP FUNCTION IF EXISTS public.fn_marketplace_complete_order(UUID, BIGINT, TEXT, TEXT, JSONB);
DROP FUNCTION IF EXISTS public.fn_marketplace_complete_order(UUID, BIGINT, TEXT, TEXT, JSONB, TEXT);

CREATE OR REPLACE FUNCTION public.fn_marketplace_complete_order(
  p_order_id UUID,
  p_provider_transaction_id BIGINT DEFAULT NULL,
  p_delivery_code TEXT DEFAULT NULL,
  p_delivery_info TEXT DEFAULT NULL,
  p_item_updates JSONB DEFAULT '[]'::jsonb,
  p_provider_order_id TEXT DEFAULT NULL
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
    provider_order_id = COALESCE(p_provider_order_id, provider_order_id),
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

GRANT EXECUTE ON FUNCTION public.fn_marketplace_complete_order TO authenticated;
