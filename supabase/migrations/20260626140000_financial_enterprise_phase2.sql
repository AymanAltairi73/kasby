-- ============================================================================
-- FINANCIAL ENTERPRISE PHASE 2
-- Agent commission, deposit proof, performance stats, SLA monitoring,
-- notification history support
-- ============================================================================

-- ── 1. Agent commissions: idempotency + withdrawal type fix ──
ALTER TABLE public.agent_commissions
  DROP CONSTRAINT IF EXISTS agent_commissions_type_check;

ALTER TABLE public.agent_commissions
  ADD CONSTRAINT agent_commissions_type_check
  CHECK (type IN ('deposit', 'withdraw', 'withdrawal'));

CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_commissions_txn_unique
  ON public.agent_commissions (transaction_id);

-- RLS: agents read own commissions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'agent_commissions'
      AND policyname = 'agents_read_own_commissions'
  ) THEN
    CREATE POLICY agents_read_own_commissions ON public.agent_commissions
      FOR SELECT USING (
        agent_id IN (SELECT id FROM agents WHERE user_id = auth.uid())
      );
  END IF;
END $$;

-- ── 2. Atomic agent commission processing ──
-- Must DROP first: prior version returned void, new version returns JSON
DROP FUNCTION IF EXISTS public.fn_process_agent_commission(UUID);

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

  -- Resolve agent from reference_id (agents.id), fallback to processed_by
  IF v_tx.reference_id IS NOT NULL THEN
    SELECT id, user_id INTO v_agent_id, v_agent_user_id
    FROM agents WHERE id::TEXT = v_tx.reference_id LIMIT 1;
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

  PERFORM public.fn_create_notification(
    v_agent_user_id,
    'تم إضافة عمولتك 💰',
    'ربحت $' || v_commission_amt || ' USD عمولة على '
      || CASE v_tx.type WHEN 'deposit' THEN 'إيداع' ELSE 'سحب' END
      || ' بقيمة $' || v_tx.amount,
    'commission_earned', 'transaction', v_commission_txn::TEXT,
    '/agent-dashboard', 'agent', 'normal'
  );

  PERFORM public.fn_log_financial_audit(
    v_agent_user_id, 'agent', 'commission_earned', p_transaction_id,
    v_tx.status, 'completed', v_commission_amt,
    jsonb_build_object(
      'commission_txn_id', v_commission_txn,
      'rate', v_commission_rate,
      'base_amount', v_tx.amount
    )
  );

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

GRANT EXECUTE ON FUNCTION public.fn_process_agent_commission(UUID) TO authenticated;

-- ── 3. Deposit request with mandatory proof URL ──
DROP FUNCTION IF EXISTS public.fn_create_deposit_request(NUMERIC, UUID, TEXT);

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

-- ── 4. Agent approve deposit (proof required + commission) ──
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
    AND reference_id = v_agent_id::TEXT
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

  PERFORM public.fn_log_financial_audit(
    v_agent_user_id, 'agent', 'deposit_approved', p_transaction_id,
    v_tx.status, 'completed', v_tx.amount, NULL
  );

  v_commission := public.fn_process_agent_commission(p_transaction_id);
  IF (v_commission->>'success')::BOOLEAN IS NOT TRUE
     AND COALESCE(v_commission->>'message', '') != 'Commission already processed' THEN
    RAISE EXCEPTION 'Commission processing failed: %', COALESCE(v_commission->>'error', 'unknown');
  END IF;

  RETURN json_build_object(
    'success', true,
    'commission', v_commission
  );
END;
$$;

-- ── 5. Agent confirm withdrawal (with commission) ──
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

  v_commission := public.fn_process_agent_commission(p_transaction_id);
  IF (v_commission->>'success')::BOOLEAN IS NOT TRUE
     AND COALESCE(v_commission->>'message', '') != 'Commission already processed' THEN
    RAISE EXCEPTION 'Commission processing failed: %', COALESCE(v_commission->>'error', 'unknown');
  END IF;

  RETURN json_build_object(
    'success', true,
    'commission', v_commission
  );
END;
$$;

-- ── 6. Admin approvals also pay assigned agent commission ──
CREATE OR REPLACE FUNCTION public.fn_process_deposit(p_txn_id UUID, p_admin_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_txn     RECORD;
  v_new_bal NUMERIC;
  v_comm    JSON;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'Unauthorized'; END IF;

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

  IF v_txn.reference_id IS NOT NULL THEN
    v_comm := public.fn_process_agent_commission(p_txn_id);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_withdrawal(p_txn_id UUID, p_admin_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_txn RECORD;
  v_comm JSON;
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

  IF v_txn.reference_id IS NOT NULL THEN
    v_comm := public.fn_process_agent_commission(p_txn_id);
  END IF;

  RETURN json_build_object('success', true, 'message', 'تمت الموافقة على السحب');
END;
$$;

-- ── 7. Agent performance dashboard RPC ──
CREATE OR REPLACE FUNCTION public.fn_get_agent_performance_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_id UUID;
  v_today    DATE := CURRENT_DATE;
  v_month_start DATE := date_trunc('month', CURRENT_DATE)::DATE;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = auth.uid() LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not an agent');
  END IF;

  RETURN (
    SELECT json_build_object(
      'success', true,
      'today_deposits', COALESCE(SUM(CASE
        WHEN tx.type = 'deposit' AND tx.status IN ('completed','approved')
          AND tx.created_at::DATE = v_today THEN 1 ELSE 0 END), 0),
      'today_withdrawals', COALESCE(SUM(CASE
        WHEN tx.type = 'withdrawal' AND tx.status = 'completed'
          AND tx.created_at::DATE = v_today THEN 1 ELSE 0 END), 0),
      'today_deposit_volume', COALESCE(SUM(CASE
        WHEN tx.type = 'deposit' AND tx.status IN ('completed','approved')
          AND tx.created_at::DATE = v_today THEN tx.amount ELSE 0 END), 0),
      'today_withdrawal_volume', COALESCE(SUM(CASE
        WHEN tx.type = 'withdrawal' AND tx.status = 'completed'
          AND tx.created_at::DATE = v_today THEN tx.amount ELSE 0 END), 0),
      'total_completed', COALESCE(SUM(CASE
        WHEN tx.status IN ('completed','approved') THEN 1 ELSE 0 END), 0),
      'total_rejected', COALESCE(SUM(CASE
        WHEN tx.status = 'rejected' THEN 1 ELSE 0 END), 0),
      'approval_rate', CASE
        WHEN COUNT(*) FILTER (WHERE tx.status IN ('completed','approved','rejected')) = 0 THEN 100
        ELSE ROUND(
          100.0 * COUNT(*) FILTER (WHERE tx.status IN ('completed','approved'))
          / NULLIF(COUNT(*) FILTER (WHERE tx.status IN ('completed','approved','rejected')), 0), 1)
      END,
      'avg_approval_minutes', COALESCE(ROUND(AVG(
        EXTRACT(EPOCH FROM (tx.processed_at - tx.created_at)) / 60
      ) FILTER (WHERE tx.processed_at IS NOT NULL AND tx.status IN ('completed','approved')), 1), 0),
      'commission_today', COALESCE((
        SELECT SUM(ac.amount) FROM agent_commissions ac
        WHERE ac.agent_id = v_agent_id AND ac.created_at::DATE = v_today
      ), 0),
      'commission_month', COALESCE((
        SELECT SUM(ac.amount) FROM agent_commissions ac
        WHERE ac.agent_id = v_agent_id AND ac.created_at >= v_month_start
      ), 0),
      'pending_count', COALESCE(SUM(CASE
        WHEN tx.status IN ('pending','processing') THEN 1 ELSE 0 END), 0)
    )
    FROM transactions tx
    WHERE tx.reference_id = v_agent_id::TEXT
      AND tx.type IN ('deposit', 'withdrawal')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_agent_performance_stats TO authenticated;

-- ── 8. Financial SLA stats (admin + agent pending list enrichment) ──
CREATE OR REPLACE FUNCTION public.fn_get_financial_sla_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_warning_mins INT := 15;
  v_overdue_mins INT := 60;
BEGIN
  RETURN (
    SELECT json_build_object(
      'success', true,
      'warning_threshold_minutes', v_warning_mins,
      'overdue_threshold_minutes', v_overdue_mins,
      'pending_total', COUNT(*),
      'pending_deposits', COUNT(*) FILTER (WHERE type = 'deposit'),
      'pending_withdrawals', COUNT(*) FILTER (WHERE type = 'withdrawal'),
      'warning_count', COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM (NOW() - created_at)) / 60 >= v_warning_mins
          AND EXTRACT(EPOCH FROM (NOW() - created_at)) / 60 < v_overdue_mins
      ),
      'overdue_count', COUNT(*) FILTER (
        WHERE EXTRACT(EPOCH FROM (NOW() - created_at)) / 60 >= v_overdue_mins
      ),
      'avg_wait_minutes', COALESCE(ROUND(AVG(
        EXTRACT(EPOCH FROM (NOW() - created_at)) / 60
      ), 1), 0),
      'oldest_wait_minutes', COALESCE(ROUND(MAX(
        EXTRACT(EPOCH FROM (NOW() - created_at)) / 60
      ), 1), 0)
    )
    FROM transactions
    WHERE type IN ('deposit', 'withdrawal')
      AND status IN ('pending', 'processing')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_financial_sla_stats TO authenticated;

-- ── 9. Paginated notification history (permanent store, no purge) ──
CREATE OR REPLACE FUNCTION public.fn_get_notification_history(
  p_limit INT DEFAULT 50,
  p_offset INT DEFAULT 0,
  p_category TEXT DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_data    JSON;
  v_total   BIGINT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM notifications n
  WHERE n.user_id = v_user_id
    AND (p_category IS NULL OR p_category = 'all' OR n.type ILIKE '%' || p_category || '%'
         OR n.entity_type = p_category);

  SELECT COALESCE(json_agg(row_to_json(sub)), '[]'::JSON) INTO v_data
  FROM (
    SELECT n.*
    FROM notifications n
    WHERE n.user_id = v_user_id
      AND (p_category IS NULL OR p_category = 'all' OR n.type ILIKE '%' || p_category || '%'
           OR n.entity_type = p_category)
    ORDER BY COALESCE(n.sent_at, n.created_at) DESC NULLS LAST
    LIMIT p_limit OFFSET p_offset
  ) sub;

  RETURN json_build_object('success', true, 'data', v_data, 'total', v_total);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_notification_history TO authenticated;

-- Prevent accidental notification deletion by authenticated users
REVOKE DELETE ON public.notifications FROM authenticated;
