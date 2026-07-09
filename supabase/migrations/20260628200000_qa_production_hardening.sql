-- QA Production Hardening
-- Fixes referral code lookup mismatch (hyphenated codes), backfills registration rewards,
-- cleans stale legacy pending transfers, drops obsolete RPC overloads.

-- ── 1. Fix referral code lookup in all financial P2P RPCs ──
CREATE OR REPLACE FUNCTION public.fn_normalize_referral_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT UPPER(REPLACE(TRIM(COALESCE(p_code, '')), '-', ''));
$$;

CREATE OR REPLACE FUNCTION public.create_transfer(
  p_amount NUMERIC,
  p_receiver_referral_code TEXT,
  p_transfer_type TEXT DEFAULT 'funds',
  p_idempotency_key TEXT DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_sender_id       UUID := auth.uid();
  v_receiver_id     UUID;
  v_receiver_name   TEXT;
  v_sender_name     TEXT;
  v_sender_wallet   RECORD;
  v_receiver_wallet RECORD;
  v_tx_out_id       UUID;
  v_tx_in_id        UUID;
  v_existing_tx_id  UUID;
  v_existing_name   TEXT;
  v_normalized_code TEXT;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid amount');
  END IF;

  v_normalized_code := fn_normalize_referral_code(p_receiver_referral_code);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT t.id, p.full_name INTO v_existing_tx_id, v_existing_name
    FROM transactions t
    LEFT JOIN profiles p ON p.id = t.counterpart_user_id
    WHERE t.idempotency_key = p_idempotency_key AND t.user_id = v_sender_id
    LIMIT 1;

    IF v_existing_tx_id IS NOT NULL THEN
      RETURN json_build_object(
        'success', TRUE,
        'message', 'Transaction already processed',
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
    IF v_sender_wallet.available_balance < p_amount THEN
      RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
    END IF;

    UPDATE wallets SET available_balance = available_balance - p_amount, updated_at = NOW()
    WHERE id = v_sender_wallet.id;

    UPDATE wallets SET available_balance = available_balance + p_amount, updated_at = NOW()
    WHERE id = v_receiver_wallet.id;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      counterpart_user_id, description, idempotency_key, running_balance
    ) VALUES (
      v_sender_id, v_sender_wallet.id, 'transfer_out', p_amount, 0, 'USD', 'completed',
      v_receiver_id, 'تحويل إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
      p_idempotency_key, v_sender_wallet.available_balance - p_amount
    ) RETURNING id INTO v_tx_out_id;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      counterpart_user_id, description, reference_id, running_balance
    ) VALUES (
      v_receiver_id, v_receiver_wallet.id, 'transfer_in', p_amount, 0, 'USD', 'completed',
      v_sender_id, 'تحويل واردة من ' || COALESCE(v_sender_name, 'مستخدم'),
      v_tx_out_id::TEXT, v_receiver_wallet.available_balance + p_amount
    ) RETURNING id INTO v_tx_in_id;

    PERFORM fn_log_financial_audit(
      v_sender_id, 'user', 'transfer_sent', v_tx_out_id,
      NULL, 'completed', p_amount,
      jsonb_build_object('receiver_id', v_receiver_id, 'transfer_in_id', v_tx_in_id)
    );
  ELSE
    RETURN json_build_object('success', FALSE, 'error', 'Use fn_transfer_ksp for points transfers');
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'transaction_id', v_tx_out_id,
    'receiver_name', v_receiver_name,
    'message', 'Transfer completed'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_transfer_ksp(
  p_amount INTEGER,
  p_receiver_referral_code TEXT,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_sender_id uuid := auth.uid();
  v_receiver_id uuid;
  v_receiver_name text;
  v_sender_name text;
  v_deduct jsonb;
  v_tx_id uuid;
  v_cached jsonb;
  v_normalized_code text;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT result_payload INTO v_cached
    FROM financial_idempotency_keys
    WHERE user_id = v_sender_id
      AND idempotency_key = p_idempotency_key
      AND operation_type = 'ksp_transfer';

    IF v_cached IS NOT NULL THEN
      RETURN v_cached::JSON;
    END IF;
  END IF;

  v_normalized_code := fn_normalize_referral_code(p_receiver_referral_code);

  SELECT id, full_name INTO v_receiver_id, v_receiver_name
  FROM profiles
  WHERE fn_normalize_referral_code(referral_code) = v_normalized_code
  LIMIT 1;

  IF v_receiver_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Receiver not found');
  END IF;

  IF v_receiver_id = v_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'Cannot transfer to yourself');
  END IF;

  SELECT full_name INTO v_sender_name FROM profiles WHERE id = v_sender_id;

  v_deduct := fn_deduct_effective_ksp(
    v_sender_id, p_amount,
    'KSP transfer to ' || COALESCE(v_receiver_name, 'user'),
    p_idempotency_key
  );

  IF COALESCE((v_deduct->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN json_build_object(
      'success', false,
      'error', COALESCE(v_deduct->>'error', 'Insufficient points')
    );
  END IF;

  PERFORM fn_credit_reward_ksp(
    v_receiver_id, p_amount,
    'KSP transfer from ' || COALESCE(v_sender_name, 'user'),
    p_idempotency_key
  );

  SELECT gen_random_uuid() INTO v_tx_id;

  PERFORM fn_create_notification(
    v_receiver_id, 'تم استلام نقاط',
    'تم تحويل ' || p_amount::text || ' KSP إليك من ' || COALESCE(v_sender_name, 'مستخدم'),
    'transfer_received', 'transaction', v_tx_id::text, '/wallet', 'user', 'normal'
  );

  PERFORM fn_create_notification(
    v_sender_id, 'تم إرسال النقاط',
    'تم تحويل ' || p_amount::text || ' KSP إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
    'transfer_sent', 'transaction', v_tx_id::text, '/wallet', 'user', 'normal'
  );

  IF p_idempotency_key IS NOT NULL THEN
    INSERT INTO financial_idempotency_keys (user_id, idempotency_key, operation_type, result_payload)
    VALUES (
      v_sender_id, p_idempotency_key, 'ksp_transfer',
      jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'receiver_name', v_receiver_name,
        'message', 'KSP transfer completed'
      )
    )
    ON CONFLICT (user_id, idempotency_key, operation_type) DO NOTHING;
  END IF;

  RETURN json_build_object(
    'success', true,
    'transaction_id', v_tx_id,
    'receiver_name', v_receiver_name,
    'message', 'KSP transfer completed'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_normalized TEXT;
  v_profile RECORD;
BEGIN
  v_normalized := fn_normalize_referral_code(p_code);

  IF v_normalized = '' OR v_normalized !~ '^K[A-Z0-9]{4,}$' THEN
    RETURN json_build_object('valid', FALSE, 'reason', 'invalid_format');
  END IF;

  SELECT id, referral_code, full_name, status
    INTO v_profile
    FROM profiles
    WHERE fn_normalize_referral_code(referral_code) = v_normalized
    LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('valid', FALSE, 'reason', 'not_found');
  END IF;

  IF v_profile.status IN ('blocked', 'suspended') THEN
    RETURN json_build_object('valid', FALSE, 'reason', 'referrer_inactive');
  END IF;

  IF auth.uid() IS NOT NULL AND v_profile.id = auth.uid() THEN
    RETURN json_build_object('valid', FALSE, 'reason', 'self_referral');
  END IF;

  RETURN json_build_object(
    'valid', TRUE,
    'referrer_id', v_profile.id,
    'referral_code', v_profile.referral_code,
    'referrer_name', v_profile.full_name
  );
END;
$$;

-- ── 2. Backfill registration rewards for users referred before migration ──
DO $$
DECLARE
  r RECORD;
  v_result JSONB;
BEGIN
  FOR r IN
    SELECT p.id AS new_user_id, p.referred_by AS referrer_id
    FROM profiles p
    WHERE p.referred_by IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM referral_registration_rewards rr WHERE rr.user_id = p.id
      )
  LOOP
    BEGIN
      v_result := process_registration_rewards(r.new_user_id, r.referrer_id);
      INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
      VALUES (
        r.new_user_id, 'system', 'referral_reward_backfill', 'referral', r.new_user_id::TEXT,
        jsonb_build_object('result', v_result, 'referrer_id', r.referrer_id),
        CASE WHEN (v_result->>'success')::boolean THEN 'info' ELSE 'warning' END
      );
    EXCEPTION WHEN OTHERS THEN
      INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
      VALUES (
        r.new_user_id, 'system', 'referral_reward_backfill_failed', 'referral', r.new_user_id::TEXT,
        jsonb_build_object('error', SQLERRM, 'referrer_id', r.referrer_id),
        'error'
      );
    END;
  END LOOP;
END $$;

-- ── 3. Cancel stale legacy pending P2P transfers (pre-enterprise flow) ──
UPDATE transactions
SET status = 'rejected',
    rejection_reason = 'Legacy pending transfer auto-cancelled during QA hardening'
WHERE type IN ('transfer_out', 'transfer_in')
  AND status = 'pending'
  AND created_at < NOW() - INTERVAL '1 day';

-- ── 4. Drop obsolete RPC overloads (prevent ambiguous resolution) ──
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.create_withdrawal(NUMERIC, UUID);
DROP FUNCTION IF EXISTS public.create_withdrawal(NUMERIC, UUID, TEXT);

GRANT EXECUTE ON FUNCTION public.fn_normalize_referral_code(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.create_transfer(NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_transfer_ksp(INTEGER, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon, authenticated;
