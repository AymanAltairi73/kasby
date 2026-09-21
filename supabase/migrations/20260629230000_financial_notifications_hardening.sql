-- Professional financial notifications for deposit / withdrawal workflows.
-- Uses fn_create_notification (realtime + FCM + deep links) for all parties.

CREATE OR REPLACE FUNCTION public.fn_create_deposit_request(
  p_amount NUMERIC,
  p_agent_id UUID,
  p_idempotency_key TEXT DEFAULT NULL,
  p_proof_url TEXT DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_wallet_id      UUID;
  v_transaction_id UUID;
  v_agent_user_id  UUID;
  v_agent_name     TEXT;
  v_user_name      TEXT;
  v_ref_short      TEXT;
  v_amount_text    TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_amount < 10 THEN
    RETURN json_build_object('success', false, 'error', 'Minimum deposit is $10');
  END IF;

  SELECT id INTO v_wallet_id FROM wallets WHERE user_id = v_user_id LIMIT 1;
  IF v_wallet_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  SELECT COALESCE(full_name, 'User') INTO v_user_name FROM profiles WHERE id = v_user_id;

  SELECT a.user_id, COALESCE(p.full_name, 'Agent')
    INTO v_agent_user_id, v_agent_name
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Agent not found or inactive');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
      FROM transactions
     WHERE idempotency_key = p_idempotency_key
       AND user_id = v_user_id
     LIMIT 1;
    IF v_transaction_id IS NOT NULL THEN
      RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
    END IF;
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key, proof_url
  ) VALUES (
    v_user_id, v_wallet_id, 'deposit', p_amount, 0, 'USD',
    'pending', p_agent_id::TEXT,
    'Deposit via agent: ' || v_agent_name,
    p_idempotency_key, p_proof_url
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets SET pending_balance = pending_balance + p_amount
    WHERE id = v_wallet_id;

  v_ref_short := UPPER(SUBSTRING(v_transaction_id::TEXT FROM 1 FOR 8));
  v_amount_text := TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM p_amount::TEXT));

  PERFORM fn_create_notification(
    v_user_id,
    'Deposit Request Submitted',
    'Your deposit request of $' || v_amount_text || ' USD to agent ' || v_agent_name || ' has been submitted. Ref: ' || v_ref_short,
    'deposit_submitted', 'transaction', v_transaction_id::TEXT, '/wallet', 'user', 'normal'
  );

  PERFORM fn_create_notification(
    v_agent_user_id,
    'New Deposit Request',
    v_user_name || ' submitted a deposit of $' || v_amount_text || ' USD awaiting your approval. Ref: ' || v_ref_short,
    'agent_deposit_pending', 'transaction', v_transaction_id::TEXT, '/agent-dashboard', 'agent', 'high'
  );

  RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_deposit_request(NUMERIC, UUID, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.create_withdrawal(
  p_amount NUMERIC,
  p_agent_id UUID,
  p_idempotency_key TEXT,
  p_currency TEXT DEFAULT 'USD'
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_wallet_id      UUID;
  v_available      NUMERIC;
  v_transaction_id UUID;
  v_agent_user_id  UUID;
  v_agent_name     TEXT;
  v_user_name      TEXT;
  v_ref_short      TEXT;
  v_amount_text    TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_amount < 10 THEN
    RETURN json_build_object('success', false, 'error', 'Minimum withdrawal is $10');
  END IF;

  SELECT id, available_balance INTO v_wallet_id, v_available
    FROM wallets WHERE user_id = v_user_id LIMIT 1;

  IF v_wallet_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  IF v_available < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  SELECT COALESCE(full_name, 'User') INTO v_user_name FROM profiles WHERE id = v_user_id;

  SELECT a.user_id, COALESCE(p.full_name, 'Agent')
    INTO v_agent_user_id, v_agent_name
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Agent not found');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
      FROM transactions
     WHERE idempotency_key = p_idempotency_key
       AND user_id = v_user_id
     LIMIT 1;
    IF v_transaction_id IS NOT NULL THEN
      RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
    END IF;
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key
  ) VALUES (
    v_user_id, v_wallet_id, 'withdrawal', p_amount, 0, p_currency,
    'pending', p_agent_id::TEXT,
    'Withdrawal via agent: ' || v_agent_name,
    p_idempotency_key
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets
    SET available_balance = available_balance - p_amount,
        pending_balance   = pending_balance + p_amount
    WHERE id = v_wallet_id;

  v_ref_short := UPPER(SUBSTRING(v_transaction_id::TEXT FROM 1 FOR 8));
  v_amount_text := TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM p_amount::TEXT));

  PERFORM fn_create_notification(
    v_user_id,
    'Withdrawal Request Submitted',
    'Your withdrawal request of $' || v_amount_text || ' USD via agent ' || v_agent_name || ' has been submitted. Ref: ' || v_ref_short,
    'withdrawal_requested', 'transaction', v_transaction_id::TEXT, '/wallet', 'user', 'normal'
  );

  PERFORM fn_create_notification(
    v_agent_user_id,
    'New Withdrawal Request',
    v_user_name || ' requested a withdrawal of $' || v_amount_text || ' USD awaiting your confirmation. Ref: ' || v_ref_short,
    'agent_withdrawal_pending', 'transaction', v_transaction_id::TEXT, '/agent-dashboard', 'agent', 'high'
  );

  RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_withdrawal(NUMERIC, UUID, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.agent_approve_deposit(p_transaction_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_user_id UUID := auth.uid();
  v_agent_id      UUID;
  v_tx            RECORD;
  v_agent_name    TEXT;
  v_ref_short     TEXT;
  v_amount_text   TEXT;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT COALESCE(full_name, 'Agent') INTO v_agent_name FROM profiles WHERE id = v_agent_user_id;

  SELECT * INTO v_tx FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT
      AND type = 'deposit'
      AND status IN ('pending', 'processing');

  IF v_tx IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  UPDATE transactions SET
    status       = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW()
    WHERE id = p_transaction_id;

  UPDATE wallets SET
    available_balance = available_balance + v_tx.amount,
    pending_balance   = GREATEST(pending_balance - v_tx.amount, 0)
    WHERE id = v_tx.wallet_id;

  UPDATE agents SET total_transactions = total_transactions + 1
    WHERE id = v_agent_id;

  v_ref_short := UPPER(SUBSTRING(p_transaction_id::TEXT FROM 1 FOR 8));
  v_amount_text := TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM v_tx.amount::TEXT));

  PERFORM fn_create_notification(
    v_tx.user_id,
    'Deposit Approved',
    'Your deposit of $' || v_amount_text || ' USD has been approved successfully by ' || v_agent_name || '. Ref: ' || v_ref_short,
    'deposit_approved', 'transaction', p_transaction_id::TEXT, '/wallet', 'user', 'high'
  );

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.agent_confirm_withdrawal(p_transaction_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_user_id UUID := auth.uid();
  v_agent_id      UUID;
  v_tx            RECORD;
  v_agent_name    TEXT;
  v_ref_short     TEXT;
  v_amount_text   TEXT;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT COALESCE(full_name, 'Agent') INTO v_agent_name FROM profiles WHERE id = v_agent_user_id;

  SELECT * INTO v_tx FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT
      AND type = 'withdrawal'
      AND status IN ('pending', 'processing');

  IF v_tx IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  UPDATE transactions SET
    status       = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW()
    WHERE id = p_transaction_id;

  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0)
    WHERE id = v_tx.wallet_id;

  UPDATE agents SET total_transactions = total_transactions + 1
    WHERE id = v_agent_id;

  v_ref_short := UPPER(SUBSTRING(p_transaction_id::TEXT FROM 1 FOR 8));
  v_amount_text := TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM v_tx.amount::TEXT));

  PERFORM fn_create_notification(
    v_tx.user_id,
    'Withdrawal Completed',
    'Your withdrawal of $' || v_amount_text || ' USD has been confirmed by ' || v_agent_name || '. Ref: ' || v_ref_short,
    'withdrawal_completed', 'transaction', p_transaction_id::TEXT, '/wallet', 'user', 'high'
  );

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.agent_reject_transaction(
  p_transaction_id UUID,
  p_reason TEXT
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_user_id UUID := auth.uid();
  v_agent_id      UUID;
  v_tx            RECORD;
  v_ref_short     TEXT;
  v_amount_text   TEXT;
  v_notif_type    TEXT;
  v_title         TEXT;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT * INTO v_tx FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT
      AND status IN ('pending', 'processing');

  IF v_tx IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  UPDATE transactions SET
    status           = 'rejected',
    rejection_reason = p_reason,
    processed_by     = v_agent_user_id,
    processed_at     = NOW()
    WHERE id = p_transaction_id;

  IF v_tx.type = 'deposit' THEN
    UPDATE wallets SET
      pending_balance = GREATEST(pending_balance - v_tx.amount, 0)
      WHERE id = v_tx.wallet_id;
    v_notif_type := 'deposit_rejected';
    v_title := 'Deposit Rejected';
  ELSIF v_tx.type = 'withdrawal' THEN
    UPDATE wallets SET
      available_balance = available_balance + v_tx.amount,
      pending_balance   = GREATEST(pending_balance - v_tx.amount, 0)
      WHERE id = v_tx.wallet_id;
    v_notif_type := 'withdrawal_rejected';
    v_title := 'Withdrawal Rejected';
  ELSE
    v_notif_type := 'warning';
    v_title := 'Transaction Rejected';
  END IF;

  v_ref_short := UPPER(SUBSTRING(p_transaction_id::TEXT FROM 1 FOR 8));
  v_amount_text := TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM v_tx.amount::TEXT));

  PERFORM fn_create_notification(
    v_tx.user_id,
    v_title,
    'Your ' || v_tx.type || ' of $' || v_amount_text || ' USD was rejected. Reason: ' || COALESCE(p_reason, 'Not specified') || '. Ref: ' || v_ref_short,
    v_notif_type, 'transaction', p_transaction_id::TEXT, '/wallet', 'user', 'high'
  );

  RETURN json_build_object('success', true);
END;
$$;
