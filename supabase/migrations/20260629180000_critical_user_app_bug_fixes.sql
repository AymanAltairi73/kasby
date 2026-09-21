-- Critical user-app bug fixes: account write access, KYC workflow, dashboard view

-- Profile KYC audit columns
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS status_reason TEXT,
  ADD COLUMN IF NOT EXISTS kyc_rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS kyc_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS kyc_verified_by UUID REFERENCES public.profiles(id);

-- USD-only dashboard view (prevents multi-wallet ambiguity for agents).
-- Must DROP first: CREATE OR REPLACE cannot reorder/rename existing view columns.
DROP VIEW IF EXISTS public.v_user_dashboard;

CREATE VIEW public.v_user_dashboard AS
SELECT
  p.id AS user_id,
  p.full_name,
  p.account_tier,
  p.kyc_status,
  w.available_balance,
  w.profit_balance,
  w.invested_balance,
  w.pending_balance,
  COALESCE(w.is_frozen, FALSE) AS is_frozen,
  w.currency,
  up.current_balance AS point_balance,
  (
    SELECT COUNT(*)::INTEGER
    FROM public.user_investments ui
    WHERE ui.user_id = p.id AND ui.status = 'active'
  ) AS active_investments,
  (
    SELECT COUNT(*)::INTEGER
    FROM public.loans l
    WHERE l.user_id = p.id AND l.status = 'current'
  ) AS active_loans,
  COALESCE((
    SELECT SUM(ROUND(ui2.amount * (ui2.profit_percentage / 100.0) / 365.0, 4))
    FROM public.user_investments ui2
    WHERE ui2.user_id = p.id AND ui2.status = 'active'
  ), 0)::NUMERIC AS daily_profit,
  COALESCE((
    SELECT AVG(ui3.profit_percentage)
    FROM public.user_investments ui3
    WHERE ui3.user_id = p.id AND ui3.status = 'active'
  ), 0)::NUMERIC AS profit_percentage,
  w.frozen_reason,
  p.status AS profile_status
FROM public.profiles p
LEFT JOIN public.wallets w
  ON w.user_id = p.id AND w.currency = 'USD'
LEFT JOIN public.user_points up ON up.user_id = p.id;

GRANT SELECT ON public.v_user_dashboard TO authenticated;

-- Authoritative write-access probe for the consumer app
CREATE OR REPLACE FUNCTION public.fn_get_account_write_access()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_profile RECORD;
  v_wallet RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'can_write', FALSE,
      'restriction_type', 'not_authenticated',
      'reason', 'Login required'
    );
  END IF;

  SELECT status, status_reason, role, kyc_status
    INTO v_profile
  FROM public.profiles
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'can_write', FALSE,
      'restriction_type', 'profile_missing',
      'reason', 'Profile not found'
    );
  END IF;

  IF v_profile.status = 'blocked' THEN
    RETURN jsonb_build_object(
      'can_write', FALSE,
      'restriction_type', 'account_blocked',
      'reason', COALESCE(NULLIF(TRIM(v_profile.status_reason), ''), 'Account blocked'),
      'profile_status', v_profile.status
    );
  END IF;

  IF v_profile.status = 'suspended' THEN
    RETURN jsonb_build_object(
      'can_write', FALSE,
      'restriction_type', 'account_suspended',
      'reason', COALESCE(NULLIF(TRIM(v_profile.status_reason), ''), 'Account suspended'),
      'profile_status', v_profile.status
    );
  END IF;

  IF v_profile.status <> 'active' THEN
    RETURN jsonb_build_object(
      'can_write', FALSE,
      'restriction_type', 'account_inactive',
      'reason', COALESCE(NULLIF(TRIM(v_profile.status_reason), ''), 'Account is not active'),
      'profile_status', v_profile.status
    );
  END IF;

  SELECT is_frozen, frozen_reason
    INTO v_wallet
  FROM public.wallets
  WHERE user_id = v_user_id AND currency = 'USD'
  LIMIT 1;

  IF v_wallet.is_frozen IS TRUE THEN
    RETURN jsonb_build_object(
      'can_write', FALSE,
      'restriction_type', 'wallet_frozen',
      'reason', COALESCE(NULLIF(TRIM(v_wallet.frozen_reason), ''), 'Wallet frozen'),
      'profile_status', v_profile.status
    );
  END IF;

  RETURN jsonb_build_object(
    'can_write', TRUE,
    'restriction_type', 'none',
    'reason', NULL,
    'profile_status', v_profile.status,
    'role', v_profile.role
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_account_write_access() TO authenticated;

-- User KYC submission
CREATE OR REPLACE FUNCTION public.fn_submit_kyc(p_full_name TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Not authenticated');
  END IF;

  UPDATE public.profiles
  SET
    kyc_status = 'pending',
    kyc_rejection_reason = NULL,
    full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
    updated_at = NOW()
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', TRUE, 'kyc_status', 'pending');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_kyc(TEXT) TO authenticated;

-- Admin: approve entire KYC request for a user (all pending documents)
CREATE OR REPLACE FUNCTION public.fn_admin_approve_user_kyc(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  UPDATE public.kyc_documents
  SET
    status = 'verified',
    reviewed_by = v_admin_id,
    reviewed_at = v_now,
    rejection_reason = NULL
  WHERE user_id = p_user_id AND status = 'pending';

  UPDATE public.profiles
  SET
    kyc_status = 'verified',
    kyc_rejection_reason = NULL,
    kyc_verified_at = v_now,
    kyc_verified_by = v_admin_id,
    account_tier = CASE WHEN account_tier = 'free' THEN 'verified' ELSE account_tier END,
    updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.activity_logs (actor_id, actor_role, action, entity_type, entity_id, details)
  VALUES (
    v_admin_id,
    'admin',
    'admin_approve_user_kyc',
    'profile',
    p_user_id::TEXT,
    jsonb_build_object('approved_at', v_now)
  );

  RETURN jsonb_build_object('success', TRUE, 'kyc_status', 'verified');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_approve_user_kyc(UUID) TO authenticated;

-- Admin: reject entire KYC request with mandatory reason
CREATE OR REPLACE FUNCTION public.fn_admin_reject_user_kyc(
  p_user_id UUID,
  p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_now TIMESTAMPTZ := NOW();
  v_reason TEXT := NULLIF(TRIM(p_reason), '');
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  IF v_reason IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Rejection reason is required');
  END IF;

  UPDATE public.kyc_documents
  SET
    status = 'rejected',
    reviewed_by = v_admin_id,
    reviewed_at = v_now,
    rejection_reason = v_reason
  WHERE user_id = p_user_id AND status IN ('pending', 'verified');

  UPDATE public.profiles
  SET
    kyc_status = 'rejected',
    kyc_rejection_reason = v_reason,
    kyc_verified_at = NULL,
    kyc_verified_by = NULL,
    updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.activity_logs (actor_id, actor_role, action, entity_type, entity_id, details)
  VALUES (
    v_admin_id,
    'admin',
    'admin_reject_user_kyc',
    'profile',
    p_user_id::TEXT,
    jsonb_build_object('reason', v_reason, 'rejected_at', v_now)
  );

  RETURN jsonb_build_object('success', TRUE, 'kyc_status', 'rejected', 'reason', v_reason);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_reject_user_kyc(UUID, TEXT) TO authenticated;

-- Restore financial permission checks on deposit / withdrawal RPCs
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
  v_user_id UUID := auth.uid();
  v_wallet_id UUID;
  v_transaction_id UUID;
  v_agent_user_id UUID;
  v_agent_name TEXT;
  v_user_name TEXT;
  v_fee_info JSONB;
  v_fee NUMERIC;
BEGIN
  PERFORM public.fn_check_financial_permission(v_user_id, 'deposit');

  IF p_amount < 10 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Minimum deposit is $10');
  END IF;

  v_fee_info := fn_calculate_fee('deposit', p_amount);
  v_fee := (v_fee_info->>'fee')::NUMERIC;

  SELECT id INTO v_wallet_id
  FROM wallets
  WHERE user_id = v_user_id AND currency = 'USD'
  LIMIT 1;

  IF v_wallet_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet not found');
  END IF;

  SELECT a.user_id, COALESCE(p.full_name, 'Agent')
    INTO v_agent_user_id, v_agent_name
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Agent not found or inactive');
  END IF;

  SELECT full_name INTO v_user_name FROM profiles WHERE id = v_user_id;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
    FROM transactions WHERE idempotency_key = p_idempotency_key LIMIT 1;
    IF v_transaction_id IS NOT NULL THEN
      RETURN json_build_object('success', TRUE, 'transaction_id', v_transaction_id, 'idempotent', TRUE);
    END IF;
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key
  ) VALUES (
    v_user_id, v_wallet_id, 'deposit', p_amount, v_fee, 'USD',
    'pending', p_agent_id,
    'إيداع عبر وكيل: ' || v_agent_name,
    p_idempotency_key
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets SET pending_balance = pending_balance + p_amount WHERE id = v_wallet_id;

  PERFORM fn_create_notification(
    v_agent_user_id,
    'طلب إيداع جديد',
    COALESCE(v_user_name, 'مستخدم') || ' قدم طلب إيداع بمبلغ $' || p_amount || ' USD',
    'agent_deposit_pending', 'transaction', v_transaction_id::TEXT, '/agent-transactions', 'agent', 'high'
  );

  PERFORM fn_log_financial_audit(
    v_user_id, 'user', 'deposit_request', v_transaction_id,
    NULL, 'pending', p_amount,
    jsonb_build_object('fee', v_fee, 'agent_id', p_agent_id)
  );

  RETURN json_build_object(
    'success', TRUE, 'transaction_id', v_transaction_id,
    'fee', v_fee, 'net_amount', (v_fee_info->>'net_amount')::NUMERIC
  );
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
  v_user_id UUID := auth.uid();
  v_wallet_id UUID;
  v_available NUMERIC;
  v_transaction_id UUID;
  v_agent_user_id UUID;
  v_agent_name TEXT;
  v_user_name TEXT;
  v_fee_info JSONB;
  v_fee NUMERIC;
  v_total_deduction NUMERIC;
BEGIN
  PERFORM public.fn_check_financial_permission(v_user_id, 'withdrawal');

  IF p_amount < 10 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Minimum withdrawal is $10');
  END IF;

  v_fee_info := fn_calculate_fee('withdraw', p_amount);
  v_fee := (v_fee_info->>'fee')::NUMERIC;
  v_total_deduction := p_amount + v_fee;

  SELECT id, available_balance INTO v_wallet_id, v_available
  FROM wallets
  WHERE user_id = v_user_id AND currency = COALESCE(p_currency, 'USD')
  LIMIT 1;

  IF v_wallet_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Wallet not found');
  END IF;

  IF v_available < v_total_deduction THEN
    RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance (includes fee)');
  END IF;

  SELECT a.user_id, COALESCE(p.full_name, 'Agent')
    INTO v_agent_user_id, v_agent_name
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Agent not found or inactive');
  END IF;

  SELECT full_name INTO v_user_name FROM profiles WHERE id = v_user_id;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
    FROM transactions WHERE idempotency_key = p_idempotency_key LIMIT 1;
    IF v_transaction_id IS NOT NULL THEN
      RETURN json_build_object('success', TRUE, 'transaction_id', v_transaction_id, 'idempotent', TRUE);
    END IF;
  END IF;

  UPDATE wallets
  SET available_balance = available_balance - v_total_deduction
  WHERE id = v_wallet_id;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key
  ) VALUES (
    v_user_id, v_wallet_id, 'withdrawal', p_amount, v_fee, COALESCE(p_currency, 'USD'),
    'pending', p_agent_id,
    'سحب عبر وكيل: ' || v_agent_name,
    p_idempotency_key
  ) RETURNING id INTO v_transaction_id;

  PERFORM fn_create_notification(
    v_agent_user_id,
    'طلب سحب جديد',
    COALESCE(v_user_name, 'مستخدم') || ' قدم طلب سحب بمبلغ $' || p_amount,
    'agent_withdrawal_pending', 'transaction', v_transaction_id::TEXT, '/agent-transactions', 'agent', 'high'
  );

  RETURN json_build_object(
    'success', TRUE, 'transaction_id', v_transaction_id,
    'fee', v_fee, 'net_amount', (v_fee_info->>'net_amount')::NUMERIC
  );
END;
$$;
