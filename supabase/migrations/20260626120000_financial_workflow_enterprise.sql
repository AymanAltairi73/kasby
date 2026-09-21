-- ============================================================================
-- FINANCIAL WORKFLOW ENTERPRISE REMEDIATION
-- Unifies deposit/withdrawal/P2P flows, fixes wallet math, notifications,
-- agent assignment, realtime publication, RLS, and audit logging.
-- ============================================================================

-- ── 1. Realtime publication for wallets + notifications ──
ALTER TABLE public.wallets REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'wallets'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- ── 2. Fix agent RLS (reference_id stores agents.id, not auth.uid) ──
DROP POLICY IF EXISTS "Agents can view assigned transactions" ON public.transactions;

-- ── 3. Audit log immutability ──
DROP TRIGGER IF EXISTS trg_prevent_audit_mutation ON public.audit_logs;
CREATE TRIGGER trg_prevent_audit_mutation
  BEFORE UPDATE OR DELETE ON public.audit_logs
  FOR EACH ROW EXECUTE FUNCTION public.fn_prevent_audit_mutation();

-- ── 4. Drop duplicate legacy FCM trigger on transactions ──
DROP TRIGGER IF EXISTS trigger_transaction_notification ON public.transactions;

-- ── 5. Financial audit helper ──
CREATE OR REPLACE FUNCTION public.fn_log_financial_audit(
  p_actor_id UUID,
  p_actor_role TEXT,
  p_action TEXT,
  p_entity_id UUID,
  p_old_status TEXT,
  p_new_status TEXT,
  p_amount NUMERIC,
  p_details JSONB DEFAULT '{}'::JSONB
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  INSERT INTO audit_logs (admin_id, action, entity_type, entity_id, type, status, details)
  VALUES (
    p_actor_id,
    p_action,
    'transaction',
    p_entity_id,
    'financial',
    p_new_status,
    COALESCE(p_details, '{}'::JSONB)::TEXT
      || ' | amount=' || COALESCE(p_amount::TEXT, '0')
      || ' | old=' || COALESCE(p_old_status, '')
      || ' | new=' || COALESCE(p_new_status, '')
      || ' | role=' || COALESCE(p_actor_role, '')
  );

  INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
  VALUES (
    p_actor_id,
    p_actor_role,
    p_action,
    'transaction',
    p_entity_id::TEXT,
    jsonb_build_object(
      'old_status', p_old_status,
      'new_status', p_new_status,
      'amount', p_amount
    ) || COALESCE(p_details, '{}'::JSONB),
    'info'
  );
END;
$$;

-- ── 6. Resolve agent user_id from agents.id stored in reference_id ──
CREATE OR REPLACE FUNCTION public.fn_agent_user_id_from_reference(p_reference_id TEXT)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT user_id FROM agents WHERE id::TEXT = p_reference_id LIMIT 1;
$$;

-- ── 7. Canonical deposit request creation ──
CREATE OR REPLACE FUNCTION public.fn_create_deposit_request(
  p_amount NUMERIC,
  p_agent_id UUID,
  p_idempotency_key TEXT DEFAULT NULL
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
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_amount < 10 THEN
    RETURN json_build_object('success', false, 'error', 'Minimum deposit is $10');
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

  SELECT a.user_id, COALESCE(p.full_name, 'Agent')
    INTO v_agent_user_id, v_agent_name
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Agent not found or inactive');
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key, proof_url
  ) VALUES (
    v_user_id, v_wallet.id, 'deposit', p_amount, 0, 'USD',
    'pending', p_agent_id::TEXT,
    'إيداع عبر وكيل: ' || v_agent_name,
    p_idempotency_key, NULL
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets SET
    pending_balance = pending_balance + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet.id;

  -- Agent notification handled by trg_transaction_notification on INSERT

  PERFORM public.fn_log_financial_audit(
    v_user_id, 'user', 'deposit_submitted', v_transaction_id,
    NULL, 'pending', p_amount,
    jsonb_build_object('agent_id', p_agent_id)
  );

  RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
END;
$$;

-- ── 8. Canonical withdrawal creation (4-arg with idempotency) ──
DROP FUNCTION IF EXISTS public.create_withdrawal(NUMERIC, UUID, TEXT, TEXT);

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

  SELECT a.user_id, COALESCE(p.full_name, 'Agent')
    INTO v_agent_user_id, v_agent_name
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Agent not found');
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

  -- Agent notification handled by trg_transaction_notification on INSERT

  PERFORM public.fn_log_financial_audit(
    v_user_id, 'user', 'withdrawal_submitted', v_transaction_id,
    NULL, 'pending', p_amount,
    jsonb_build_object('agent_id', p_agent_id)
  );

  RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ── 9. Agent approve deposit ──
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
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT * INTO v_tx FROM transactions
  WHERE id = p_transaction_id
    AND reference_id = v_agent_id::TEXT
    AND type = 'deposit'
    AND status IN ('pending', 'processing')
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
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

  PERFORM public.fn_log_financial_audit(
    v_agent_user_id, 'agent', 'deposit_approved', p_transaction_id,
    v_tx.status, 'completed', v_tx.amount, NULL
  );

  RETURN json_build_object('success', true);
END;
$$;

-- ── 10. Agent confirm withdrawal ──
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
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not an agent');
  END IF;

  SELECT * INTO v_tx FROM transactions
  WHERE id = p_transaction_id
    AND reference_id = v_agent_id::TEXT
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

  PERFORM public.fn_log_financial_audit(
    v_agent_user_id, 'agent', 'withdrawal_approved', p_transaction_id,
    v_tx.status, 'completed', v_tx.amount, NULL
  );

  RETURN json_build_object('success', true);
END;
$$;

-- ── 11. Agent reject transaction (reason required) ──
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
    AND reference_id = v_agent_id::TEXT
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

  PERFORM public.fn_log_financial_audit(
    v_agent_user_id, 'agent', v_tx.type || '_rejected', p_transaction_id,
    v_tx.status, 'rejected', v_tx.amount,
    jsonb_build_object('reason', TRIM(p_reason))
  );

  RETURN json_build_object('success', true);
END;
$$;

-- ── 12. Admin approve deposit (fixes pending_balance drift, uses completed) ──
CREATE OR REPLACE FUNCTION public.fn_process_deposit(p_txn_id UUID, p_admin_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_txn     RECORD;
  v_new_bal NUMERIC;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_txn
  FROM transactions
  WHERE id = p_txn_id AND type = 'deposit' AND status IN ('pending', 'processing')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transaction % not found or already processed.', p_txn_id;
  END IF;

  PERFORM id FROM wallets WHERE id = v_txn.wallet_id FOR UPDATE;

  UPDATE wallets SET
    available_balance = available_balance + v_txn.amount - COALESCE(v_txn.fee, 0),
    pending_balance = GREATEST(pending_balance - v_txn.amount, 0),
    updated_at = NOW()
  WHERE id = v_txn.wallet_id;

  SELECT available_balance INTO v_new_bal FROM wallets WHERE id = v_txn.wallet_id;

  UPDATE transactions SET
    status = 'completed',
    running_balance = v_new_bal,
    processed_by = p_admin_id,
    processed_at = NOW()
  WHERE id = p_txn_id;

  PERFORM public.fn_log_financial_audit(
    p_admin_id, 'admin', 'deposit_approved', p_txn_id,
    v_txn.status, 'completed', v_txn.amount, NULL
  );
END;
$$;

-- ── 13. Admin reject transaction with wallet reversal ──
CREATE OR REPLACE FUNCTION public.fn_reject_transaction(
  p_txn_id UUID,
  p_admin_id UUID,
  p_reason TEXT DEFAULT 'رفض بواسطة المدير'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tx RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Rejection reason is required');
  END IF;

  SELECT * INTO v_tx FROM transactions WHERE id = p_txn_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction not found');
  END IF;

  IF v_tx.status NOT IN ('pending', 'processing') THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transaction already processed');
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
    processed_by = p_admin_id,
    processed_at = NOW()
  WHERE id = p_txn_id;

  PERFORM public.fn_log_financial_audit(
    p_admin_id, 'admin', v_tx.type || '_rejected', p_txn_id,
    v_tx.status, 'rejected', v_tx.amount,
    jsonb_build_object('reason', TRIM(p_reason))
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ── 14. Admin approve/reject withdrawal (remove duplicate notifications) ──
CREATE OR REPLACE FUNCTION public.approve_withdrawal(p_txn_id UUID, p_admin_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_txn RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_txn FROM transactions WHERE id = p_txn_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'المعاملة غير موجودة');
  END IF;

  IF v_txn.status != 'pending' OR v_txn.type != 'withdrawal' THEN
    RETURN json_build_object('success', false, 'error', 'هذه المعاملة غير متاحة للموافقة');
  END IF;

  PERFORM id FROM wallets WHERE id = v_txn.wallet_id FOR UPDATE;

  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_txn.amount, 0),
    updated_at = NOW()
  WHERE id = v_txn.wallet_id;

  UPDATE transactions SET
    status = 'completed',
    processed_by = p_admin_id,
    processed_at = NOW()
  WHERE id = p_txn_id;

  PERFORM public.fn_log_financial_audit(
    p_admin_id, 'admin', 'withdrawal_approved', p_txn_id,
    v_txn.status, 'completed', v_txn.amount, NULL
  );

  RETURN json_build_object('success', true, 'message', 'تمت الموافقة على السحب');
END;
$$;

CREATE OR REPLACE FUNCTION public.reject_withdrawal(
  p_txn_id UUID,
  p_admin_id UUID,
  p_reason TEXT DEFAULT 'تم رفض طلب السحب من قبل الإدارة'
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_txn  RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Rejection reason is required');
  END IF;

  SELECT * INTO v_txn FROM transactions WHERE id = p_txn_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'المعاملة غير موجودة');
  END IF;

  IF v_txn.status != 'pending' OR v_txn.type != 'withdrawal' THEN
    RETURN json_build_object('success', false, 'error', 'هذه المعاملة لا يمكن رفضها');
  END IF;

  PERFORM id FROM wallets WHERE id = v_txn.wallet_id FOR UPDATE;

  UPDATE transactions SET
    status = 'rejected',
    rejection_reason = TRIM(p_reason),
    processed_by = p_admin_id,
    processed_at = NOW()
  WHERE id = p_txn_id;

  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_txn.amount, 0),
    available_balance = available_balance + v_txn.amount,
    updated_at = NOW()
  WHERE id = v_txn.wallet_id;

  PERFORM public.fn_log_financial_audit(
    p_admin_id, 'admin', 'withdrawal_rejected', p_txn_id,
    v_txn.status, 'rejected', v_txn.amount,
    jsonb_build_object('reason', TRIM(p_reason))
  );

  RETURN json_build_object('success', true, 'message', 'تم رفض طلب السحب وإعادة المبلغ للمحفظة.');
END;
$$;

-- ── 15. Atomic P2P transfer with idempotency + notifications ──
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT, TEXT, TEXT) CASCADE;

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
  v_sender_points   NUMERIC;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'Invalid amount');
  END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing_tx_id
    FROM transactions
    WHERE idempotency_key = p_idempotency_key AND user_id = v_sender_id
    LIMIT 1;
    IF v_existing_tx_id IS NOT NULL THEN
      RETURN json_build_object(
        'success', true,
        'message', 'Transaction already processed',
        'transaction_id', v_existing_tx_id
      );
    END IF;
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

  IF p_transfer_type = 'funds' THEN
    PERFORM public.fn_check_financial_permission(v_sender_id, 'transfer');

    SELECT * INTO v_sender_wallet FROM wallets
    WHERE user_id = v_sender_id AND currency = 'USD' FOR UPDATE;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'error', 'Wallet not found');
    END IF;
    IF v_sender_wallet.is_frozen THEN
      RETURN json_build_object('success', false, 'error', 'Wallet is frozen');
    END IF;
    IF v_sender_wallet.available_balance < p_amount THEN
      RETURN json_build_object('success', false, 'error', 'Insufficient balance');
    END IF;

    SELECT * INTO v_receiver_wallet FROM wallets
    WHERE user_id = v_receiver_id AND currency = 'USD' FOR UPDATE;

    IF NOT FOUND THEN
      PERFORM public.ensure_user_wallet(v_receiver_id);
      SELECT * INTO v_receiver_wallet FROM wallets
      WHERE user_id = v_receiver_id AND currency = 'USD' FOR UPDATE;
    END IF;

    UPDATE wallets SET
      available_balance = available_balance - p_amount,
      updated_at = NOW()
    WHERE id = v_sender_wallet.id;

    UPDATE wallets SET
      available_balance = available_balance + p_amount,
      updated_at = NOW()
    WHERE id = v_receiver_wallet.id;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency,
      status, counterpart_user_id, description, idempotency_key, running_balance
    ) VALUES (
      v_sender_id, v_sender_wallet.id, 'transfer_out', p_amount, 0, 'USD',
      'completed', v_receiver_id,
      'تحويل إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
      p_idempotency_key,
      v_sender_wallet.available_balance - p_amount
    ) RETURNING id INTO v_tx_out_id;

    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency,
      status, counterpart_user_id, description, reference_id, running_balance
    ) VALUES (
      v_receiver_id, v_receiver_wallet.id, 'transfer_in', p_amount, 0, 'USD',
      'completed', v_sender_id,
      'تحويل واردة من ' || COALESCE(v_sender_name, 'مستخدم'),
      v_tx_out_id::TEXT,
      v_receiver_wallet.available_balance + p_amount
    ) RETURNING id INTO v_tx_in_id;

    -- Notifications handled by trg_transaction_notification on INSERT

    PERFORM public.fn_log_financial_audit(
      v_sender_id, 'user', 'transfer_sent', v_tx_out_id,
      NULL, 'completed', p_amount,
      jsonb_build_object('receiver_id', v_receiver_id)
    );

  ELSIF p_transfer_type = 'points' THEN
    SELECT current_balance INTO v_sender_points
    FROM user_points WHERE user_id = v_sender_id FOR UPDATE;

    IF v_sender_points IS NULL OR v_sender_points < p_amount THEN
      RETURN json_build_object('success', false, 'error', 'Insufficient points');
    END IF;

    UPDATE user_points SET current_balance = current_balance - p_amount
    WHERE user_id = v_sender_id;

    INSERT INTO user_points (user_id, current_balance)
    VALUES (v_receiver_id, p_amount)
    ON CONFLICT (user_id) DO UPDATE
      SET current_balance = user_points.current_balance + EXCLUDED.current_balance;

    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_sender_id, -p_amount, 'spend', 'تحويل نقاط إلى ' || v_receiver_name);

    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_receiver_id, p_amount, 'earn', 'نقاط محوّلة من ' || COALESCE(v_sender_name, 'مستخدم'));

    SELECT gen_random_uuid() INTO v_tx_out_id;

    PERFORM public.fn_create_notification(
      v_receiver_id,
      'تم استلام نقاط',
      'تم تحويل ' || p_amount::INT || ' نقطة إليك',
      'transfer_received', 'transaction', v_tx_out_id::TEXT, '/wallet', 'user', 'normal'
    );

    PERFORM public.fn_create_notification(
      v_sender_id,
      'تم إرسال النقاط',
      'تم تحويل ' || p_amount::INT || ' نقطة إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
      'transfer_sent', 'transaction', v_tx_out_id::TEXT, '/wallet', 'user', 'normal'
    );
  ELSE
    RETURN json_build_object('success', false, 'error', 'Invalid transfer type');
  END IF;

  RETURN json_build_object(
    'success', true,
    'transaction_id', v_tx_out_id,
    'receiver_name', v_receiver_name,
    'message', 'تم التحويل بنجاح'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ── 16. Agent dashboard query RPC (paginated, filtered) ──
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
  v_agent_id   UUID;
  v_total      BIGINT;
  v_data       JSON;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = auth.uid() LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not an agent');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM transactions tx
  LEFT JOIN profiles p ON p.id = tx.user_id
  WHERE tx.reference_id = v_agent_id::TEXT
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
    WHERE tx.reference_id = v_agent_id::TEXT
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

GRANT EXECUTE ON FUNCTION public.fn_get_agent_transactions TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_log_financial_audit TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_agent_user_id_from_reference TO authenticated;

-- ── 17. Transaction notification trigger (deposit completed + agent fix) ──
CREATE OR REPLACE FUNCTION public.fn_trigger_transaction_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_ids    UUID[];
  v_agent_user_id UUID;
BEGIN
  -- Deposit approved/completed
  IF NEW.type = 'deposit'
     AND NEW.status IN ('approved', 'completed')
     AND (OLD IS NULL OR OLD.status NOT IN ('approved', 'completed')) THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'تمت الموافقة على الإيداع ✅',
      'تم إيداع $' || NEW.amount || ' في محفظتك بنجاح.',
      'deposit_approved', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'deposit' AND NEW.status = 'rejected'
     AND (OLD IS NULL OR OLD.status != 'rejected') THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'تم رفض الإيداع ❌',
      'تم رفض طلب الإيداع: ' || COALESCE(NEW.rejection_reason, 'يرجى التواصل مع الدعم'),
      'deposit_rejected', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'withdrawal' AND NEW.status = 'completed'
     AND (OLD IS NULL OR OLD.status != 'completed') THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'تم تنفيذ السحب ✅',
      'تم سحب $' || NEW.amount || ' بنجاح.',
      'withdrawal_completed', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'withdrawal' AND NEW.status = 'rejected'
     AND (OLD IS NULL OR OLD.status != 'rejected') THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'تم رفض السحب ❌',
      'تم رفض طلب السحب: ' || COALESCE(NEW.rejection_reason, 'يرجى التواصل مع الدعم'),
      'withdrawal_rejected', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'transfer_in' AND NEW.status = 'completed' AND TG_OP = 'INSERT' THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'تحويل واردة 💸',
      'تم استلام $' || NEW.amount || ' من تحويل.',
      'transfer_received', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'transfer_out' AND NEW.status = 'completed' AND TG_OP = 'INSERT' THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'تم إرسال التحويل ✅',
      'تم إرسال $' || NEW.amount || ' بنجاح.',
      'transfer_sent', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'profit' AND NEW.status = 'completed' AND TG_OP = 'INSERT' THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'أرباح يومية 📈',
      'تم إضافة $' || NEW.amount || ' أرباح إلى محفظتك.',
      'daily_profit', 'transaction', NEW.id::TEXT, '/wallet', 'user', 'low'
    );
  END IF;

  IF NEW.type = 'investment_return' AND NEW.status = 'completed' AND TG_OP = 'INSERT' THEN
    PERFORM public.fn_create_notification(
      NEW.user_id,
      'استثمارك نضج! 🎉',
      'تم إرجاع $' || NEW.amount || ' من الاستثمار إلى محفظتك.',
      'investment_matured', 'transaction', NEW.id::TEXT, '/investments'
    );
  END IF;

  -- Admin notifications on new pending items
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    SELECT ARRAY_AGG(id) INTO v_admin_ids
    FROM admin_profiles WHERE is_active = TRUE;

    IF v_admin_ids IS NOT NULL THEN
      IF NEW.type = 'deposit' THEN
        PERFORM public.fn_create_bulk_notification(
          v_admin_ids,
          'إيداع جديد بانتظار المراجعة 📥',
          'طلب إيداع بقيمة $' || NEW.amount || ' بانتظار الموافقة.',
          'admin_deposit_pending', 'transaction', NEW.id::TEXT,
          '/transactions', 'admin', 'high'
        );
      ELSIF NEW.type = 'withdrawal' THEN
        PERFORM public.fn_create_bulk_notification(
          v_admin_ids,
          'سحب جديد بانتظار المراجعة 📤',
          'طلب سحب بقيمة $' || NEW.amount || ' بانتظار الموافقة.',
          'admin_withdrawal_pending', 'transaction', NEW.id::TEXT,
          '/transactions', 'admin', 'high'
        );
      END IF;
    END IF;

    -- Agent notification on new assigned deposit/withdrawal (lookup user_id from agents.id)
    IF NEW.type IN ('deposit', 'withdrawal') AND NEW.reference_id IS NOT NULL THEN
      v_agent_user_id := public.fn_agent_user_id_from_reference(NEW.reference_id);
      IF v_agent_user_id IS NOT NULL THEN
        PERFORM public.fn_create_notification(
          v_agent_user_id,
          CASE NEW.type
            WHEN 'deposit' THEN 'طلب إيداع جديد 📥'
            ELSE 'طلب سحب جديد 📤'
          END,
          CASE NEW.type
            WHEN 'deposit' THEN 'طلب إيداع بقيمة $' || NEW.amount || ' بانتظار موافقتك'
            ELSE 'طلب سحب بقيمة $' || NEW.amount || ' بانتظار تأكيدك'
          END,
          CASE NEW.type
            WHEN 'deposit' THEN 'agent_deposit_pending'
            ELSE 'agent_withdrawal_pending'
          END,
          'transaction', NEW.id::TEXT, '/agent-dashboard', 'agent', 'high'
        );
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Fix reference_id type consistency for existing rows where user_id was stored
UPDATE transactions tx
SET reference_id = a.id::TEXT
FROM agents a
WHERE tx.reference_id = a.user_id::TEXT
  AND tx.type IN ('deposit', 'withdrawal')
  AND tx.status IN ('pending', 'processing', 'completed', 'rejected', 'approved');
