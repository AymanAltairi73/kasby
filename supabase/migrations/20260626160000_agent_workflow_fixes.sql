-- ============================================================================
-- AGENT WORKFLOW FIXES
-- Fix approve/reject failures, commission notifications, availability gating
-- ============================================================================

-- ── 1. Allow commission_earned + legacy notification types ──
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Normalize orphan/legacy notification types before re-adding CHECK constraint
UPDATE public.notifications SET type = 'system' WHERE type IS NOT NULL AND BTRIM(type) = '';

UPDATE public.notifications SET type = 'transfer_sent' WHERE type = 'financial';

UPDATE public.notifications SET type = 'warning' WHERE type = 'error';

UPDATE public.notifications
SET type = 'system'
WHERE type IS NOT NULL
  AND type NOT IN (
    'deposit_submitted', 'deposit_approved', 'deposit_rejected',
    'withdrawal_requested', 'withdrawal_approved', 'withdrawal_rejected', 'withdrawal_completed',
    'transfer_received', 'transfer_sent',
    'loan_requested', 'loan_approved', 'loan_rejected', 'loan_repayment_due', 'loan_overdue', 'loan_paid',
    'investment_created', 'daily_profit', 'investment_matured', 'investment_cancelled',
    'chat_new_message', 'chat_admin_reply', 'chat_resolved', 'chat_escalated',
    'kyc_approved', 'kyc_rejected', 'account_flagged', 'account_frozen', 'account_deleted', 'account_unblocked',
    'role_upgraded', 'referral_bonus', 'profile_updated',
    'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change', 'commission_earned',
    'admin_kyc_pending', 'admin_withdrawal_pending', 'admin_deposit_pending', 'admin_flagged_user',
    'admin_new_chat', 'admin_investment_pending',
    'social_friend_request', 'social_friend_accepted', 'social_chat',
    'system', 'maintenance', 'announcement', 'security_alert', 'info', 'success', 'warning', 'critical',
    'reward', 'notification', 'wheel_reminder', 'checkin_reminder',
    'financial', 'error'
  );

ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (
  type IS NULL OR type = ANY (ARRAY[
    'deposit_submitted', 'deposit_approved', 'deposit_rejected',
    'withdrawal_requested', 'withdrawal_approved', 'withdrawal_rejected', 'withdrawal_completed',
    'transfer_received', 'transfer_sent',
    'loan_requested', 'loan_approved', 'loan_rejected', 'loan_repayment_due', 'loan_overdue', 'loan_paid',
    'investment_created', 'daily_profit', 'investment_matured', 'investment_cancelled',
    'chat_new_message', 'chat_admin_reply', 'chat_resolved', 'chat_escalated',
    'kyc_approved', 'kyc_rejected', 'account_flagged', 'account_frozen', 'account_deleted', 'account_unblocked',
    'role_upgraded', 'referral_bonus', 'profile_updated',
    'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change', 'commission_earned',
    'admin_kyc_pending', 'admin_withdrawal_pending', 'admin_deposit_pending', 'admin_flagged_user',
    'admin_new_chat', 'admin_investment_pending',
    'social_friend_request', 'social_friend_accepted', 'social_chat',
    'system', 'maintenance', 'announcement', 'security_alert', 'info', 'success', 'warning', 'critical',
    'reward', 'notification', 'wheel_reminder', 'checkin_reminder',
    'financial', 'error'
  ]::TEXT[])
);

-- ── 2. Match agent transactions (agents.id or legacy user_id in reference_id) ──
CREATE OR REPLACE FUNCTION public.fn_tx_belongs_to_agent(
  p_reference_id TEXT,
  p_agent_id UUID,
  p_agent_user_id UUID
) RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT p_reference_id IS NOT NULL AND (
    p_reference_id = p_agent_id::TEXT
    OR p_reference_id = p_agent_user_id::TEXT
  );
$$;

-- ── 3. Commission: use allowed notification type + resilient errors ──
CREATE OR REPLACE FUNCTION public.fn_process_agent_commission(p_transaction_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tx              RECORD;
  v_agent_id        UUID;
  v_agent_user_id   UUID;
  v_commission_rate NUMERIC;
  v_commission_amt  NUMERIC;
  v_commission_type TEXT;
  v_agent_wallet_id UUID;
  v_commission_txn  UUID;
  v_new_bal         NUMERIC;
BEGIN
  IF EXISTS (
    SELECT 1 FROM agent_commissions WHERE transaction_id = p_transaction_id
  ) THEN
    RETURN json_build_object('success', true, 'message', 'Commission already processed');
  END IF;

  SELECT * INTO v_tx FROM transactions WHERE id = p_transaction_id FOR UPDATE;

  IF NOT FOUND OR v_tx.status NOT IN ('completed', 'approved') THEN
    RETURN json_build_object('success', false, 'error', 'Transaction not completed');
  END IF;

  IF v_tx.type NOT IN ('deposit', 'withdrawal') THEN
    RETURN json_build_object('success', false, 'error', 'Not a commission-eligible transaction');
  END IF;

  IF v_tx.reference_id IS NOT NULL THEN
    SELECT id, user_id INTO v_agent_id, v_agent_user_id
    FROM agents
    WHERE id::TEXT = v_tx.reference_id OR user_id::TEXT = v_tx.reference_id
    LIMIT 1;
  END IF;

  IF v_agent_id IS NULL AND v_tx.processed_by IS NOT NULL THEN
    SELECT id, user_id INTO v_agent_id, v_agent_user_id
    FROM agents WHERE user_id = v_tx.processed_by LIMIT 1;
  END IF;

  IF v_agent_id IS NULL OR v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'No agent assigned');
  END IF;

  IF v_tx.type = 'deposit' THEN
    v_commission_rate := 1.0;
    v_commission_type := 'deposit';
  ELSE
    v_commission_rate := 1.5;
    v_commission_type := 'withdraw';
  END IF;

  v_commission_amt := ROUND(v_tx.amount * (v_commission_rate / 100), 4);
  IF v_commission_amt <= 0 THEN
    RETURN json_build_object('success', true, 'message', 'Zero commission');
  END IF;

  v_agent_wallet_id := public.ensure_user_wallet(v_agent_user_id);
  PERFORM id FROM wallets WHERE id = v_agent_wallet_id FOR UPDATE;

  INSERT INTO agent_commissions (agent_id, transaction_id, amount, percentage, type)
  VALUES (v_agent_id, p_transaction_id, v_commission_amt, v_commission_rate, v_commission_type);

  UPDATE agents SET
    total_commission_earned = total_commission_earned + v_commission_amt,
    available_cash = available_cash + v_commission_amt,
    updated_at = NOW()
  WHERE id = v_agent_id;

  UPDATE wallets SET
    available_balance = available_balance + v_commission_amt,
    updated_at = NOW()
  WHERE id = v_agent_wallet_id
  RETURNING available_balance INTO v_new_bal;

  v_commission_txn := gen_random_uuid();
  INSERT INTO transactions (
    id, user_id, wallet_id, type, amount, fee, currency, status,
    description, reference_id, running_balance
  ) VALUES (
    v_commission_txn, v_agent_user_id, v_agent_wallet_id, 'reward',
    v_commission_amt, 0, 'USD', 'completed',
    'عمولة ' || CASE v_tx.type WHEN 'deposit' THEN 'إيداع' ELSE 'سحب' END
      || ' — $' || v_tx.amount,
    p_transaction_id::TEXT, v_new_bal
  );

  BEGIN
    PERFORM public.fn_create_notification(
      v_agent_user_id,
      'تم إضافة عمولتك 💰',
      'ربحت $' || v_commission_amt || ' USD عمولة على '
        || CASE v_tx.type WHEN 'deposit' THEN 'إيداع' ELSE 'سحب' END
        || ' بقيمة $' || v_tx.amount,
      'commission_earned', 'transaction', v_commission_txn::TEXT,
      '/agent-dashboard', 'agent', 'normal'
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_agent_user_id, 'agent', 'commission_earned', p_transaction_id,
      v_tx.status, 'completed', v_commission_amt,
      jsonb_build_object(
        'commission_txn_id', v_commission_txn,
        'rate', v_commission_rate,
        'base_amount', v_tx.amount
      )
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN json_build_object(
    'success', true,
    'commission_amount', v_commission_amt,
    'commission_transaction_id', v_commission_txn
  );
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('success', true, 'message', 'Commission already processed');
WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ── 4. Agent approve deposit (non-blocking commission) ──
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
  v_new_bal       NUMERIC;
  v_commission    JSON;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT * INTO v_tx FROM transactions
  WHERE id = p_transaction_id
    AND public.fn_tx_belongs_to_agent(reference_id, v_agent_id, v_agent_user_id)
    AND type = 'deposit'
    AND status IN ('pending', 'processing')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  IF v_tx.proof_url IS NULL OR TRIM(v_tx.proof_url) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Deposit proof is required before approval');
  END IF;

  PERFORM id FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;

  UPDATE wallets SET
    available_balance = available_balance + v_tx.amount,
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
    updated_at = NOW()
  WHERE id = v_tx.wallet_id;

  SELECT available_balance INTO v_new_bal FROM wallets WHERE id = v_tx.wallet_id;

  UPDATE transactions SET
    status = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW(),
    running_balance = v_new_bal
  WHERE id = p_transaction_id;

  UPDATE agents SET total_transactions = total_transactions + 1 WHERE id = v_agent_id;

  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_agent_user_id, 'agent', 'deposit_approved', p_transaction_id,
      v_tx.status, 'completed', v_tx.amount, NULL
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  v_commission := public.fn_process_agent_commission(p_transaction_id);

  RETURN json_build_object(
    'success', true,
    'commission', v_commission,
    'commission_warning', CASE
      WHEN (v_commission->>'success')::BOOLEAN IS NOT TRUE
        AND COALESCE(v_commission->>'message', '') != 'Commission already processed'
      THEN COALESCE(v_commission->>'error', v_commission->>'message', 'Commission deferred')
      ELSE NULL
    END
  );
END;
$$;

-- ── 5. Agent confirm withdrawal ──
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
  v_commission    JSON;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT * INTO v_tx FROM transactions
  WHERE id = p_transaction_id
    AND public.fn_tx_belongs_to_agent(reference_id, v_agent_id, v_agent_user_id)
    AND type = 'withdrawal'
    AND status IN ('pending', 'processing')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  PERFORM id FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;

  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
    updated_at = NOW()
  WHERE id = v_tx.wallet_id;

  UPDATE transactions SET
    status = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW()
  WHERE id = p_transaction_id;

  UPDATE agents SET total_transactions = total_transactions + 1 WHERE id = v_agent_id;

  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_agent_user_id, 'agent', 'withdrawal_approved', p_transaction_id,
      v_tx.status, 'completed', v_tx.amount, NULL
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  v_commission := public.fn_process_agent_commission(p_transaction_id);

  RETURN json_build_object(
    'success', true,
    'commission', v_commission,
    'commission_warning', CASE
      WHEN (v_commission->>'success')::BOOLEAN IS NOT TRUE
        AND COALESCE(v_commission->>'message', '') != 'Commission already processed'
      THEN COALESCE(v_commission->>'error', v_commission->>'message', 'Commission deferred')
      ELSE NULL
    END
  );
END;
$$;

-- ── 6. Agent reject transaction ──
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
BEGIN
  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Rejection reason is required');
  END IF;

  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT * INTO v_tx FROM transactions
  WHERE id = p_transaction_id
    AND public.fn_tx_belongs_to_agent(reference_id, v_agent_id, v_agent_user_id)
    AND status IN ('pending', 'processing')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  PERFORM id FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;

  IF v_tx.type = 'deposit' THEN
    UPDATE wallets SET
      pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
      updated_at = NOW()
    WHERE id = v_tx.wallet_id;
  ELSIF v_tx.type = 'withdrawal' THEN
    UPDATE wallets SET
      available_balance = available_balance + v_tx.amount,
      pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
      updated_at = NOW()
    WHERE id = v_tx.wallet_id;
  END IF;

  UPDATE transactions SET
    status = 'rejected',
    rejection_reason = TRIM(p_reason),
    processed_by = v_agent_user_id,
    processed_at = NOW()
  WHERE id = p_transaction_id;

  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_agent_user_id, 'agent', v_tx.type || '_rejected', p_transaction_id,
      v_tx.status, 'rejected', v_tx.amount,
      jsonb_build_object('reason', TRIM(p_reason))
    );
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 7. Agent transaction list (legacy reference_id support) ──
CREATE OR REPLACE FUNCTION public.fn_get_agent_transactions(
  p_status TEXT DEFAULT 'pending',
  p_type TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_id       UUID;
  v_agent_user_id  UUID;
  v_total          BIGINT;
  v_data           JSON;
BEGIN
  SELECT id, user_id INTO v_agent_id, v_agent_user_id
  FROM agents WHERE user_id = auth.uid() LIMIT 1;

  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not an agent');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM transactions tx
  LEFT JOIN profiles p ON p.id = tx.user_id
  WHERE public.fn_tx_belongs_to_agent(tx.reference_id, v_agent_id, v_agent_user_id)
    AND tx.type IN ('deposit', 'withdrawal')
    AND (
      p_status = 'all'
      OR (p_status = 'pending' AND tx.status IN ('pending', 'processing'))
      OR (p_status = 'approved' AND tx.status IN ('completed', 'approved'))
      OR (p_status = 'rejected' AND tx.status = 'rejected')
    )
    AND (p_type IS NULL OR tx.type = p_type)
    AND (
      p_search IS NULL OR TRIM(p_search) = ''
      OR p.full_name ILIKE '%' || p_search || '%'
      OR tx.id::TEXT ILIKE '%' || p_search || '%'
      OR tx.user_id::TEXT ILIKE '%' || p_search || '%'
    );

  SELECT COALESCE(json_agg(row_to_json(sub)), '[]'::JSON) INTO v_data
  FROM (
    SELECT
      tx.*,
      p.full_name AS user_name,
      p.phone AS user_phone,
      p.email AS user_email
    FROM transactions tx
    LEFT JOIN profiles p ON p.id = tx.user_id
    WHERE public.fn_tx_belongs_to_agent(tx.reference_id, v_agent_id, v_agent_user_id)
      AND tx.type IN ('deposit', 'withdrawal')
      AND (
        p_status = 'all'
        OR (p_status = 'pending' AND tx.status IN ('pending', 'processing'))
        OR (p_status = 'approved' AND tx.status IN ('completed', 'approved'))
        OR (p_status = 'rejected' AND tx.status = 'rejected')
      )
      AND (p_type IS NULL OR tx.type = p_type)
      AND (
        p_search IS NULL OR TRIM(p_search) = ''
        OR p.full_name ILIKE '%' || p_search || '%'
        OR tx.id::TEXT ILIKE '%' || p_search || '%'
        OR tx.user_id::TEXT ILIKE '%' || p_search || '%'
      )
    ORDER BY tx.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) sub;

  RETURN json_build_object('success', true, 'data', v_data, 'total', v_total);
END;
$$;

-- ── 8. Only online agents receive new deposit/withdrawal requests ──
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
  v_wallet         RECORD;
  v_transaction_id UUID;
  v_agent_user_id  UUID;
  v_agent_name     TEXT;
  v_agent_online   BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_amount < 10 THEN
    RETURN json_build_object('success', false, 'error', 'Minimum deposit is $10');
  END IF;

  IF p_proof_url IS NULL OR TRIM(p_proof_url) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Deposit proof image is required');
  END IF;

  PERFORM public.fn_check_financial_permission(v_user_id, 'deposit');

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
      FROM transactions WHERE idempotency_key = p_idempotency_key AND user_id = v_user_id LIMIT 1;
    IF v_transaction_id IS NOT NULL THEN
      RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
    END IF;
  END IF;

  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_user_id AND currency = 'USD' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Wallet not found');
  END IF;
  IF v_wallet.is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'Wallet is frozen');
  END IF;

  SELECT a.user_id, COALESCE(p.full_name, 'Agent'), a.is_available_now
    INTO v_agent_user_id, v_agent_name, v_agent_online
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Agent not found or inactive');
  END IF;

  IF COALESCE(v_agent_online, false) IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'error', 'Agent is currently offline');
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key, proof_url
  ) VALUES (
    v_user_id, v_wallet.id, 'deposit', p_amount, 0, 'USD',
    'pending', p_agent_id::TEXT,
    'إيداع عبر وكيل: ' || v_agent_name,
    p_idempotency_key, TRIM(p_proof_url)
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets SET
    pending_balance = pending_balance + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet.id;

  PERFORM public.fn_log_financial_audit(
    v_user_id, 'user', 'deposit_submitted', v_transaction_id,
    NULL, 'pending', p_amount,
    jsonb_build_object('agent_id', p_agent_id, 'has_proof', true)
  );

  RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
END;
$$;

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
  v_wallet         RECORD;
  v_transaction_id UUID;
  v_agent_user_id  UUID;
  v_agent_name     TEXT;
  v_agent_online   BOOLEAN;
  v_pending_count  INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  PERFORM public.fn_check_financial_permission(v_user_id, 'withdrawal');

  IF p_amount < 10 THEN
    RETURN json_build_object('success', false, 'error', 'Minimum withdrawal is $10');
  END IF;

  SELECT COUNT(*) INTO v_pending_count
  FROM transactions
  WHERE user_id = v_user_id AND type = 'withdrawal'
    AND status IN ('pending', 'locked', 'processing');
  IF v_pending_count > 0 THEN
    RETURN json_build_object('success', false, 'error', 'You already have a pending withdrawal');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
      FROM transactions WHERE idempotency_key = p_idempotency_key AND user_id = v_user_id LIMIT 1;
    IF v_transaction_id IS NOT NULL THEN
      RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
    END IF;
  END IF;

  SELECT * INTO v_wallet FROM wallets
  WHERE user_id = v_user_id AND currency = p_currency FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Wallet not found');
  END IF;
  IF v_wallet.is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'Wallet is frozen');
  END IF;
  IF v_wallet.available_balance < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'Insufficient balance');
  END IF;

  SELECT a.user_id, COALESCE(p.full_name, 'Agent'), a.is_available_now
    INTO v_agent_user_id, v_agent_name, v_agent_online
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Agent not found');
  END IF;

  IF COALESCE(v_agent_online, false) IS NOT TRUE THEN
    RETURN json_build_object('success', false, 'error', 'Agent is currently offline');
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key, running_balance
  ) VALUES (
    v_user_id, v_wallet.id, 'withdrawal', p_amount, 0, p_currency,
    'pending', p_agent_id::TEXT,
    'سحب عبر وكيل: ' || v_agent_name,
    p_idempotency_key,
    v_wallet.available_balance - p_amount
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets SET
    available_balance = available_balance - p_amount,
    pending_balance = pending_balance + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet.id;

  PERFORM public.fn_log_financial_audit(
    v_user_id, 'user', 'withdrawal_submitted', v_transaction_id,
    NULL, 'pending', p_amount,
    jsonb_build_object('agent_id', p_agent_id)
  );

  RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
END;
$$;

-- ── 9. Backfill legacy reference_id values ──
UPDATE transactions tx
SET reference_id = a.id::TEXT
FROM agents a
WHERE tx.reference_id = a.user_id::TEXT
  AND tx.type IN ('deposit', 'withdrawal');

-- ── 10. Grants ──
GRANT EXECUTE ON FUNCTION public.fn_tx_belongs_to_agent(TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_approve_deposit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_confirm_withdrawal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_reject_transaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_agent_transactions(TEXT, TEXT, TEXT, INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_deposit_request(NUMERIC, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_withdrawal(NUMERIC, UUID, TEXT, TEXT) TO authenticated;
