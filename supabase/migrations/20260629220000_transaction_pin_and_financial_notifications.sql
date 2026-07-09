-- Transaction PIN (server-side bcrypt) + bilateral transfer notifications.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.user_transaction_security (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  pin_hash TEXT,
  failed_attempts INT NOT NULL DEFAULT 0,
  locked_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_transaction_security ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own transaction security" ON public.user_transaction_security;
CREATE POLICY "Users read own transaction security"
  ON public.user_transaction_security FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- Mutations only through SECURITY DEFINER RPCs.

CREATE OR REPLACE FUNCTION public.fn_transaction_pin_status()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_row public.user_transaction_security%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_row FROM public.user_transaction_security WHERE user_id = v_user_id;

  IF NOT FOUND OR v_row.pin_hash IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'has_pin', false,
      'locked', false,
      'attempts_remaining', 5
    );
  END IF;

  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > NOW() THEN
    RETURN jsonb_build_object(
      'success', true,
      'has_pin', true,
      'locked', true,
      'locked_until', v_row.locked_until,
      'attempts_remaining', 0
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'has_pin', true,
    'locked', false,
    'attempts_remaining', GREATEST(0, 5 - COALESCE(v_row.failed_attempts, 0))
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_set_transaction_pin(p_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;

  INSERT INTO public.user_transaction_security (user_id, pin_hash, failed_attempts, locked_until, updated_at)
  VALUES (v_user_id, crypt(p_pin, gen_salt('bf', 10)), 0, NULL, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    pin_hash = crypt(p_pin, gen_salt('bf', 10)),
    failed_attempts = 0,
    locked_until = NULL,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_verify_transaction_pin(p_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_row public.user_transaction_security%ROWTYPE;
  v_remaining INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized', 'retry', false);
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid PIN format', 'retry', true);
  END IF;

  SELECT * INTO v_row FROM public.user_transaction_security WHERE user_id = v_user_id FOR UPDATE;

  IF NOT FOUND OR v_row.pin_hash IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN not configured', 'retry', false);
  END IF;

  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > NOW() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'PIN temporarily locked',
      'locked', true,
      'locked_until', v_row.locked_until,
      'retry', false
    );
  END IF;

  IF v_row.pin_hash = crypt(p_pin, v_row.pin_hash) THEN
    UPDATE public.user_transaction_security
    SET failed_attempts = 0, locked_until = NULL, updated_at = NOW()
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object('success', true);
  END IF;

  UPDATE public.user_transaction_security
  SET failed_attempts = failed_attempts + 1,
      locked_until = CASE
        WHEN failed_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes'
        ELSE locked_until
      END,
      updated_at = NOW()
  WHERE user_id = v_user_id
  RETURNING failed_attempts, locked_until INTO v_row.failed_attempts, v_row.locked_until;

  v_remaining := GREATEST(0, 5 - v_row.failed_attempts);

  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > NOW() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Too many failed attempts',
      'locked', true,
      'locked_until', v_row.locked_until,
      'attempts_remaining', 0,
      'retry', false
    );
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'Incorrect PIN',
    'attempts_remaining', v_remaining,
    'retry', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_transaction_pin_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_set_transaction_pin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_verify_transaction_pin(TEXT) TO authenticated;

-- ── Enhanced bilateral transfer notifications (reference + names + amount) ───
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.create_transfer(
  p_amount NUMERIC,
  p_receiver_referral_code TEXT,
  p_transfer_type TEXT DEFAULT 'funds',
  p_idempotency_key TEXT DEFAULT NULL,
  p_fee_category TEXT DEFAULT 'transfer'
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_receiver_id UUID;
  v_receiver_name TEXT;
  v_sender_name TEXT;
  v_sender_wallet RECORD;
  v_receiver_wallet RECORD;
  v_tx_out_id UUID;
  v_tx_in_id UUID;
  v_existing_tx_id UUID;
  v_existing_name TEXT;
  v_normalized_code TEXT;
  v_fee_info JSONB;
  v_fee NUMERIC;
  v_total_debit NUMERIC;
  v_fee_cat TEXT := COALESCE(NULLIF(p_fee_category, ''), 'transfer');
  v_ref_short TEXT;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid amount');
  END IF;

  v_fee_info := fn_calculate_fee(v_fee_cat, p_amount);
  v_fee := (v_fee_info->>'fee')::NUMERIC;
  v_total_debit := p_amount + v_fee;

  v_normalized_code := fn_normalize_referral_code(p_receiver_referral_code);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT t.id, p.full_name INTO v_existing_tx_id, v_existing_name
    FROM transactions t
    LEFT JOIN profiles p ON p.id = t.counterpart_user_id
    WHERE t.idempotency_key = p_idempotency_key AND t.user_id = v_sender_id
    LIMIT 1;

    IF v_existing_tx_id IS NOT NULL THEN
      RETURN json_build_object(
        'success', TRUE, 'message', 'Transaction already processed',
        'transaction_id', v_existing_tx_id,
        'receiver_name', COALESCE(v_existing_name, '')
      );
    END IF;
  END IF;

  SELECT id, full_name INTO v_receiver_id, v_receiver_name
  FROM profiles
  WHERE fn_normalize_referral_code(referral_code) = v_normalized_code
  LIMIT 1;

  IF v_receiver_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Receiver not found');
  END IF;

  IF v_receiver_id = v_sender_id THEN
    RETURN json_build_object('success', FALSE, 'error', 'Cannot transfer to yourself');
  END IF;

  SELECT full_name INTO v_sender_name FROM profiles WHERE id = v_sender_id;

  IF p_transfer_type = 'funds' THEN
    PERFORM fn_check_financial_permission(v_sender_id, 'transfer');

    IF v_sender_id < v_receiver_id THEN
      SELECT * INTO v_sender_wallet FROM wallets
      WHERE user_id = v_sender_id AND currency = 'USD' FOR UPDATE;
      IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Wallet not found');
      END IF;
      SELECT * INTO v_receiver_wallet FROM wallets
      WHERE user_id = v_receiver_id AND currency = 'USD' FOR UPDATE;
    ELSE
      SELECT * INTO v_receiver_wallet FROM wallets
      WHERE user_id = v_receiver_id AND currency = 'USD' FOR UPDATE;
      SELECT * INTO v_sender_wallet FROM wallets
      WHERE user_id = v_sender_id AND currency = 'USD' FOR UPDATE;
      IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'Wallet not found');
      END IF;
    END IF;

    IF NOT FOUND THEN
      PERFORM ensure_user_wallet(v_receiver_id);
      SELECT * INTO v_receiver_wallet FROM wallets
      WHERE user_id = v_receiver_id AND currency = 'USD' FOR UPDATE;
    END IF;

    IF v_sender_wallet.is_frozen THEN
      RETURN json_build_object('success', FALSE, 'error', 'Wallet is frozen');
    END IF;
    IF v_sender_wallet.available_balance < v_total_debit THEN
      RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance (includes fee)');
    END IF;

    UPDATE wallets SET available_balance = available_balance - v_total_debit, updated_at = NOW()
    WHERE id = v_sender_wallet.id;

    UPDATE wallets SET available_balance = available_balance + p_amount, updated_at = NOW()
    WHERE id = v_receiver_wallet.id;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      counterpart_user_id, description, idempotency_key, running_balance
    ) VALUES (
      v_sender_id, v_sender_wallet.id, 'transfer_out', p_amount, v_fee, 'USD', 'completed',
      v_receiver_id, 'Transfer to ' || COALESCE(v_receiver_name, 'User'),
      p_idempotency_key, v_sender_wallet.available_balance - v_total_debit
    ) RETURNING id INTO v_tx_out_id;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      counterpart_user_id, description, reference_id, running_balance
    ) VALUES (
      v_receiver_id, v_receiver_wallet.id, 'transfer_in', p_amount, 0, 'USD', 'completed',
      v_sender_id, 'Transfer from ' || COALESCE(v_sender_name, 'User'),
      v_tx_out_id::TEXT, v_receiver_wallet.available_balance + p_amount
    ) RETURNING id INTO v_tx_in_id;

    v_ref_short := UPPER(SUBSTRING(v_tx_out_id::TEXT FROM 1 FOR 8));

    PERFORM fn_log_financial_audit(
      v_sender_id, 'user', 'transfer_sent', v_tx_out_id,
      NULL, 'completed', p_amount,
      jsonb_build_object('receiver_id', v_receiver_id, 'fee', v_fee, 'transfer_in_id', v_tx_in_id)
    );

    PERFORM fn_create_notification(
      v_receiver_id,
      'Transfer Received',
      COALESCE(v_sender_name, 'User') || ' sent you $' || TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM p_amount::TEXT)) || ' USD. Ref: ' || v_ref_short,
      'transfer_received', 'transaction', v_tx_in_id::TEXT, '/wallet', 'user', 'normal'
    );

    PERFORM fn_create_notification(
      v_sender_id,
      'Transfer Completed',
      'Your transfer of $' || TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM p_amount::TEXT)) || ' USD to ' || COALESCE(v_receiver_name, 'User') || ' was completed. Ref: ' || v_ref_short,
      'transfer_sent', 'transaction', v_tx_out_id::TEXT, '/wallet', 'user', 'normal'
    );
  ELSE
    RETURN json_build_object('success', FALSE, 'error', 'Use fn_transfer_ksp for points transfers');
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'transaction_id', v_tx_out_id,
    'receiver_name', v_receiver_name,
    'fee', v_fee,
    'total_debit', v_total_debit,
    'message', 'Transfer completed'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_transfer(NUMERIC, TEXT, TEXT, TEXT, TEXT) TO authenticated;
