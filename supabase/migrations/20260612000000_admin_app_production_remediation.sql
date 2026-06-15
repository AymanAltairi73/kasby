-- ============================================================================
-- Kasby Admin App — Production Remediation Migration
-- Balance RPCs, dashboard metrics, loan admin repayment, bulk notifications,
-- scheduled dispatch, realtime publication, profile roles
-- ============================================================================

-- Profile role column (owner/worker/agent/user/admin)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user';

-- ── Admin balance functions (service_role only via admin-proxy) ──
-- Existing deployments may use VOID return type; must drop before changing to JSONB.
DROP FUNCTION IF EXISTS public.fn_admin_add_balance(UUID, NUMERIC);
DROP FUNCTION IF EXISTS public.fn_admin_deduct_balance(UUID, NUMERIC);

CREATE OR REPLACE FUNCTION public.fn_admin_add_balance(
  p_user_id UUID,
  p_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet RECORD;
  v_admin_id UUID := auth.uid();
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'المبلغ غير صالح');
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id AND currency = 'USD'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المحفظة غير موجودة');
  END IF;

  UPDATE public.wallets
  SET available_balance = COALESCE(available_balance, 0) + p_amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  INSERT INTO public.transactions (
    user_id, wallet_id, type, amount, status, description, processed_by
  ) VALUES (
    p_user_id,
    v_wallet.id,
    'admin_credit',
    p_amount,
    'completed',
    'Admin balance credit',
    v_admin_id
  );

  INSERT INTO public.system_logs (
    actor_id, actor_role, action, entity_type, entity_id, details, severity
  ) VALUES (
    v_admin_id,
    'admin',
    'admin_add_balance',
    'wallet',
    v_wallet.id::TEXT,
    jsonb_build_object('user_id', p_user_id, 'amount', p_amount),
    'info'
  );

  RETURN jsonb_build_object('success', true, 'message', 'تم إضافة الرصيد');
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_deduct_balance(
  p_user_id UUID,
  p_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_wallet RECORD;
  v_admin_id UUID := auth.uid();
  v_available NUMERIC;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'المبلغ غير صالح');
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = p_user_id AND currency = 'USD'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المحفظة غير موجودة');
  END IF;

  v_available := COALESCE(v_wallet.available_balance, 0);
  IF v_available < p_amount THEN
    RETURN jsonb_build_object('success', false, 'message', 'Insufficient balance');
  END IF;

  UPDATE public.wallets
  SET available_balance = v_available - p_amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  INSERT INTO public.transactions (
    user_id, wallet_id, type, amount, status, description, processed_by
  ) VALUES (
    p_user_id,
    v_wallet.id,
    'admin_debit',
    p_amount,
    'completed',
    'Admin balance debit',
    v_admin_id
  );

  INSERT INTO public.system_logs (
    actor_id, actor_role, action, entity_type, entity_id, details, severity
  ) VALUES (
    v_admin_id,
    'admin',
    'admin_deduct_balance',
    'wallet',
    v_wallet.id::TEXT,
    jsonb_build_object('user_id', p_user_id, 'amount', p_amount),
    'info'
  );

  RETURN jsonb_build_object('success', true, 'message', 'تم خصم الرصيد');
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_add_balance(UUID, NUMERIC) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_admin_deduct_balance(UUID, NUMERIC) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_add_balance(UUID, NUMERIC) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_deduct_balance(UUID, NUMERIC) TO service_role;

-- ── Dashboard RPC (extended metrics) ──
-- Return row shape changed (added total_profits, pending_txns, daily_volume).
DROP FUNCTION IF EXISTS public.fn_admin_dashboard() CASCADE;

CREATE OR REPLACE FUNCTION public.fn_admin_dashboard()
RETURNS TABLE (
  total_users BIGINT,
  active_users BIGINT,
  pending_kyc BIGINT,
  total_balance NUMERIC,
  total_invested NUMERIC,
  total_profits NUMERIC,
  pending_txns BIGINT,
  daily_volume NUMERIC,
  active_loans BIGINT,
  delayed_loans BIGINT,
  active_agents BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.profiles WHERE role IS DISTINCT FROM 'admin'),
    (SELECT COUNT(*) FROM public.profiles WHERE status = 'active' AND role IS DISTINCT FROM 'admin'),
    (SELECT COUNT(*) FROM public.kyc_documents WHERE status = 'pending'),
    (SELECT COALESCE(SUM(available_balance), 0) FROM public.wallets),
    (SELECT COALESCE(SUM(invested_balance), 0) FROM public.wallets),
    (SELECT COALESCE(SUM(profit_balance), 0) FROM public.wallets),
    (SELECT COUNT(*) FROM public.transactions WHERE status = 'pending'),
    (
      SELECT COALESCE(SUM(amount), 0)
      FROM public.transactions
      WHERE status IN ('completed', 'approved')
        AND created_at >= date_trunc('day', NOW())
        AND type IN ('deposit', 'withdrawal')
    ),
    (SELECT COUNT(*) FROM public.loans WHERE status IN ('active', 'current', 'partial_paid', 'approved')),
    (SELECT COUNT(*) FROM public.loans WHERE status IN ('delayed', 'overdue', 'defaulted')),
    (SELECT COUNT(*) FROM public.agents WHERE status = 'active');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_dashboard() TO authenticated, service_role;

-- ── 7-day transaction volume for dashboard chart ──
CREATE OR REPLACE FUNCTION public.fn_admin_weekly_volume()
RETURNS TABLE (
  day_index INT,
  day_label TEXT,
  deposit_volume NUMERIC,
  withdrawal_volume NUMERIC,
  total_volume NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH days AS (
    SELECT generate_series(6, 0, -1) AS idx
  )
  SELECT
    d.idx::INT,
    to_char((CURRENT_DATE - d.idx), 'Dy') AS day_label,
    COALESCE((
      SELECT SUM(t.amount)
      FROM public.transactions t
      WHERE t.type = 'deposit'
        AND t.status IN ('completed', 'approved')
        AND t.created_at::DATE = (CURRENT_DATE - d.idx)
    ), 0),
    COALESCE((
      SELECT SUM(t.amount)
      FROM public.transactions t
      WHERE t.type = 'withdrawal'
        AND t.status IN ('completed', 'approved')
        AND t.created_at::DATE = (CURRENT_DATE - d.idx)
    ), 0),
    COALESCE((
      SELECT SUM(t.amount)
      FROM public.transactions t
      WHERE t.type IN ('deposit', 'withdrawal')
        AND t.status IN ('completed', 'approved')
        AND t.created_at::DATE = (CURRENT_DATE - d.idx)
    ), 0)
  FROM days d
  ORDER BY d.idx ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_weekly_volume() TO authenticated, service_role;

-- ── Admin manual loan repayment (single atomic entry point) ──
CREATE OR REPLACE FUNCTION public.fn_admin_record_loan_repayment(
  p_loan_id UUID,
  p_amount NUMERIC,
  p_payment_method TEXT DEFAULT 'manual',
  p_notes TEXT DEFAULT NULL,
  p_receipt_id TEXT DEFAULT NULL,
  p_type TEXT DEFAULT 'partial',
  p_recorded_by UUID DEFAULT NULL,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_loan RECORD;
  v_existing UUID;
  v_new_remaining NUMERIC;
BEGIN
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing
    FROM public.loan_repayments
    WHERE idempotency_key = p_idempotency_key AND loan_id = p_loan_id
    LIMIT 1;
    IF v_existing IS NOT NULL THEN
      RETURN jsonb_build_object('success', true, 'message', 'تم تنفيذ هذه العملية مسبقاً', 'repayment_id', v_existing);
    END IF;
  END IF;

  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'القرض غير موجود');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'مبلغ السداد غير صالح');
  END IF;

  IF p_amount > COALESCE(v_loan.remaining_amount, v_loan.amount) THEN
    RETURN jsonb_build_object('success', false, 'message', 'المبلغ أكبر من المتبقي');
  END IF;

  v_new_remaining := COALESCE(v_loan.remaining_amount, v_loan.amount) - p_amount;

  INSERT INTO public.loan_repayments (
    loan_id, user_id, amount, payment_method, notes, receipt_id, type,
    recorded_by, previous_remaining, new_remaining, idempotency_key
  ) VALUES (
    p_loan_id,
    v_loan.user_id,
    p_amount,
    p_payment_method,
    p_notes,
    p_receipt_id,
    p_type,
    p_recorded_by,
    COALESCE(v_loan.remaining_amount, v_loan.amount),
    v_new_remaining,
    p_idempotency_key
  );

  UPDATE public.loans
  SET
    paid_amount = COALESCE(paid_amount, 0) + p_amount,
    remaining_amount = v_new_remaining,
    status = CASE WHEN v_new_remaining <= 0 THEN 'paid' ELSE 'partial_paid' END,
    paid_at = CASE WHEN v_new_remaining <= 0 THEN NOW() ELSE paid_at END,
    updated_at = NOW()
  WHERE id = p_loan_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تسجيل السداد',
    'remaining', v_new_remaining
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_record_loan_repayment(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT, UUID, TEXT)
  TO authenticated, service_role;

-- ── Bulk notification insert ──
CREATE OR REPLACE FUNCTION public.fn_create_bulk_notification(
  p_user_ids UUID[],
  p_title TEXT,
  p_message TEXT,
  p_target TEXT DEFAULT 'all',
  p_sent_by UUID DEFAULT NULL,
  p_status TEXT DEFAULT 'sent',
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT := 0;
  v_uid UUID;
  v_sent_at TIMESTAMPTZ := COALESCE(p_scheduled_at, NOW());
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  FOREACH v_uid IN ARRAY p_user_ids LOOP
    INSERT INTO public.notifications (
      user_id, title, message, target, type, sent_at, status, sent_by
    ) VALUES (
      v_uid, p_title, p_message, p_target, 'notification', v_sent_at, p_status, p_sent_by
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_bulk_notification(UUID[], TEXT, TEXT, TEXT, UUID, TEXT, TIMESTAMPTZ)
  TO authenticated, service_role;

-- ── Dispatch scheduled notifications (callable by pg_cron or edge worker) ──
CREATE OR REPLACE FUNCTION public.fn_dispatch_scheduled_notifications()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  UPDATE public.notifications
  SET status = 'sent', sent_at = NOW()
  WHERE status = 'scheduled'
    AND sent_at IS NOT NULL
    AND sent_at <= NOW();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN COALESCE(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_dispatch_scheduled_notifications() TO service_role;

-- ── Realtime publication ──
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'user_investments'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_investments;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_conversations;
  END IF;
END $$;
