-- Marketplace KSP checkout uses unified effective balance deduction.

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
