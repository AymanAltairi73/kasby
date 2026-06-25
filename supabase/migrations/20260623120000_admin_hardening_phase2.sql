-- Kasby Admin Hardening Phase 2
-- Legacy role cleanup, fraud schema, wallet freeze RPCs, admin tier helpers

-- ─── 1. Legacy admin tier cleanup ───────────────────────────────────────────
UPDATE public.admin_profiles SET role = 'admin' WHERE role = 'superadmin';
UPDATE public.admin_profiles SET role = 'admin' WHERE role IN ('finance_ops', 'support');

ALTER TABLE public.admin_profiles DROP CONSTRAINT IF EXISTS admin_profiles_role_check;
ALTER TABLE public.admin_profiles
  ADD CONSTRAINT admin_profiles_role_check
  CHECK (role = ANY (ARRAY['admin'::text, 'viewer'::text]));

-- ─── 2. Fraud visibility columns ────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS risk_score integer NOT NULL DEFAULT 0;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_flagged boolean NOT NULL DEFAULT false;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_risk_score_check CHECK (risk_score >= 0 AND risk_score <= 100);

-- ─── 3. Account flags ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.account_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reason text NOT NULL,
  flagged_by uuid REFERENCES public.profiles(id),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  cleared_at timestamptz,
  cleared_by uuid REFERENCES public.profiles(id),
  clear_reason text
);

CREATE INDEX IF NOT EXISTS idx_account_flags_user_active
  ON public.account_flags(user_id) WHERE is_active = true;

-- ─── 4. Wallet freeze history ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wallet_freeze_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('freeze', 'unfreeze')),
  reason text,
  actor_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wallet_freeze_events_user
  ON public.wallet_freeze_events(user_id, created_at DESC);

-- ─── 5. Reconciliation notes ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wallet_reconciliation_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  admin_id uuid NOT NULL REFERENCES public.profiles(id),
  notes text NOT NULL,
  reconciliation_result jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ─── 6. Admin tier helpers ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin_tier()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_role text;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN false;
  END IF;

  SELECT role INTO v_role
  FROM public.admin_profiles
  WHERE id = auth.uid();

  IF NOT FOUND THEN
    RETURN true;
  END IF;

  RETURN v_role = 'admin';
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_require_admin_tier()
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  IF NOT public.is_admin_tier() THEN
    RAISE EXCEPTION 'RBAC_DENIED: Insufficient admin privileges';
  END IF;
END;
$$;

-- ─── 7. Wallet freeze / unfreeze ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_freeze_wallet(
  p_user_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  PERFORM public.fn_require_admin_tier();

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Freeze reason is required';
  END IF;

  UPDATE public.wallets
  SET
    is_frozen = true,
    frozen_reason = btrim(p_reason),
    frozen_at = now(),
    frozen_by = v_admin_id,
    updated_at = now()
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;

  INSERT INTO public.wallet_freeze_events (user_id, action, reason, actor_id)
  VALUES (p_user_id, 'freeze', btrim(p_reason), v_admin_id);

  INSERT INTO public.system_logs (actor_id, action, entity_type, entity_id, severity, details)
  VALUES (
    v_admin_id,
    'wallet_freeze',
    'wallet',
    p_user_id::text,
    'warning',
    jsonb_build_object('reason', btrim(p_reason))
  );

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'is_frozen', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_unfreeze_wallet(
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  PERFORM public.fn_require_admin_tier();

  UPDATE public.wallets
  SET
    is_frozen = false,
    frozen_reason = NULL,
    frozen_at = NULL,
    frozen_by = NULL,
    updated_at = now()
  WHERE user_id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Wallet not found';
  END IF;

  INSERT INTO public.wallet_freeze_events (user_id, action, reason, actor_id)
  VALUES (p_user_id, 'unfreeze', p_reason, v_admin_id);

  INSERT INTO public.system_logs (actor_id, action, entity_type, entity_id, severity, details)
  VALUES (
    v_admin_id,
    'wallet_unfreeze',
    'wallet',
    p_user_id::text,
    'info',
    jsonb_build_object('reason', p_reason)
  );

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'is_frozen', false);
END;
$$;

-- ─── 8. Account flag RPCs ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_set_account_flag(
  p_user_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  PERFORM public.fn_require_admin_tier();

  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Flag reason is required';
  END IF;

  UPDATE public.account_flags
  SET is_active = false, cleared_at = now(), cleared_by = v_admin_id, clear_reason = 'superseded'
  WHERE user_id = p_user_id AND is_active = true;

  INSERT INTO public.account_flags (user_id, reason, flagged_by, is_active)
  VALUES (p_user_id, btrim(p_reason), v_admin_id, true);

  UPDATE public.profiles
  SET is_flagged = true, risk_score = GREATEST(risk_score, 70)
  WHERE id = p_user_id;

  INSERT INTO public.system_logs (actor_id, action, entity_type, entity_id, severity, details)
  VALUES (
    v_admin_id,
    'user_flag',
    'user',
    p_user_id::text,
    'warning',
    jsonb_build_object('reason', btrim(p_reason))
  );

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'is_flagged', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_clear_account_flag(
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id uuid := auth.uid();
BEGIN
  PERFORM public.fn_require_admin_tier();

  UPDATE public.account_flags
  SET is_active = false, cleared_at = now(), cleared_by = v_admin_id, clear_reason = p_reason
  WHERE user_id = p_user_id AND is_active = true;

  UPDATE public.profiles
  SET is_flagged = false
  WHERE id = p_user_id;

  INSERT INTO public.system_logs (actor_id, action, entity_type, entity_id, severity, details)
  VALUES (
    v_admin_id,
    'user_unflag',
    'user',
    p_user_id::text,
    'info',
    jsonb_build_object('reason', p_reason)
  );

  RETURN jsonb_build_object('success', true, 'user_id', p_user_id, 'is_flagged', false);
END;
$$;

-- ─── 9. Fraud metrics RPC ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_get_fraud_metrics()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_flagged integer;
  v_high_risk integer;
  v_medium_risk integer;
  v_low_risk integer;
  v_open_flags integer;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT COUNT(*) INTO v_flagged FROM public.profiles WHERE is_flagged = true;
  SELECT COUNT(*) INTO v_high_risk FROM public.profiles WHERE risk_score >= 70 AND role = 'user';
  SELECT COUNT(*) INTO v_medium_risk FROM public.profiles WHERE risk_score BETWEEN 40 AND 69 AND role = 'user';
  SELECT COUNT(*) INTO v_low_risk FROM public.profiles WHERE risk_score < 40 AND role = 'user';
  SELECT COUNT(*) INTO v_open_flags FROM public.account_flags WHERE is_active = true;

  RETURN jsonb_build_object(
    'flagged_accounts', v_flagged,
    'open_flags', v_open_flags,
    'high_risk', v_high_risk,
    'medium_risk', v_medium_risk,
    'low_risk', v_low_risk
  );
END;
$$;

-- ─── 10. Reconcile wallet — require admin tier + audit ───────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_reconcile_wallet(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
    v_wallet RECORD;
    v_calc_available NUMERIC(18,4) := 0;
    v_calc_invested NUMERIC(18,4) := 0;
    v_calc_pending NUMERIC(18,4) := 0;
    v_calc_profit NUMERIC(18,4) := 0;
    v_result jsonb;
    v_match boolean;
BEGIN
    PERFORM public.fn_require_admin_tier();

    SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not found';
    END IF;

    SELECT COALESCE(SUM(
        CASE
            WHEN type IN ('deposit', 'transfer_in', 'profit', 'admin_credit', 'investment_return', 'loan_disbursement', 'reversal')
                AND status IN ('completed', 'approved') THEN amount
            WHEN type IN ('withdrawal', 'transfer_out', 'investment', 'fee', 'admin_debit', 'loan_repayment', 'compensation')
                AND status IN ('completed', 'approved') THEN -amount
            ELSE 0
        END
    ), 0) INTO v_calc_available
    FROM public.transactions WHERE user_id = p_user_id;

    SELECT COALESCE(SUM(amount), 0) INTO v_calc_invested
    FROM public.user_investments WHERE user_id = p_user_id AND status IN ('active', 'collateral_locked');

    SELECT COALESCE(SUM(amount), 0) INTO v_calc_pending
    FROM public.transactions WHERE user_id = p_user_id AND type = 'withdrawal' AND status = 'pending';

    SELECT COALESCE(SUM(amount), 0) INTO v_calc_profit
    FROM public.transactions WHERE user_id = p_user_id AND type = 'profit' AND status = 'completed';

    v_match := (
        ABS(v_wallet.available_balance - (v_calc_available - v_calc_invested - v_calc_pending)) < 0.01
        AND ABS(v_wallet.invested_balance - v_calc_invested) < 0.01
        AND ABS(v_wallet.pending_balance - v_calc_pending) < 0.01
    );

    v_result := jsonb_build_object(
        'user_id', p_user_id,
        'wallet', jsonb_build_object(
            'available', v_wallet.available_balance,
            'invested', v_wallet.invested_balance,
            'pending', v_wallet.pending_balance,
            'profit', v_wallet.profit_balance
        ),
        'calculated', jsonb_build_object(
            'available', v_calc_available - v_calc_invested - v_calc_pending,
            'invested', v_calc_invested,
            'pending', v_calc_pending,
            'profit', v_calc_profit
        ),
        'match', v_match,
        'status', CASE WHEN v_match THEN 'balanced' WHEN ABS(v_wallet.available_balance - (v_calc_available - v_calc_invested - v_calc_pending)) < 1 THEN 'warning' ELSE 'mismatch' END
    );

    INSERT INTO public.system_logs (actor_id, action, entity_type, entity_id, severity, details)
    VALUES (
        auth.uid(),
        'wallet_reconcile',
        'wallet',
        p_user_id::text,
        CASE WHEN v_match THEN 'info' ELSE 'warning' END,
        v_result
    );

    RETURN v_result;
END;
$$;

-- ─── 11. User-facing wallet restriction message ──────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_check_financial_permission(p_user_id uuid, p_operation text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
    v_profile RECORD;
    v_wallet RECORD;
    v_settings RECORD;
BEGIN
    SELECT status, kyc_status, role INTO v_profile
    FROM public.profiles WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Profile not found for user %', p_user_id;
    END IF;

    IF v_profile.status != 'active' THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Account is %. Contact support.', v_profile.status;
    END IF;

    IF p_operation IN ('withdrawal', 'investment', 'loan') THEN
        IF v_profile.kyc_status != 'verified' THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: KYC verification required. Current status: %', v_profile.kyc_status;
        END IF;
    END IF;

    SELECT is_frozen INTO v_wallet
    FROM public.wallets WHERE user_id = p_user_id;

    IF v_wallet.is_frozen THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Your wallet is temporarily restricted. Please contact support.';
    END IF;

    SELECT * INTO v_settings FROM public.system_settings LIMIT 1;

    IF v_settings.system_freeze THEN
        RAISE EXCEPTION 'SYSTEM_FROZEN: All operations are temporarily suspended.';
    END IF;

    IF p_operation = 'withdrawal' AND v_settings.pause_withdrawals THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Withdrawals are temporarily paused.';
    END IF;

    IF p_operation = 'investment' AND v_settings.pause_investments THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Investments are temporarily paused.';
    END IF;

    IF p_operation = 'loan' AND v_settings.pause_loans THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Loans are temporarily paused.';
    END IF;

    IF p_operation = 'deposit' AND v_settings.pause_deposits THEN
        RAISE EXCEPTION 'SYSTEM_PAUSED: Deposits are temporarily paused.';
    END IF;

    IF p_operation = 'transfer' AND v_wallet.is_frozen THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Your wallet is temporarily restricted. Please contact support.';
    END IF;

    IF p_operation = 'marketplace' AND v_wallet.is_frozen THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Your wallet is temporarily restricted. Please contact support.';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_tier() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_require_admin_tier() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_freeze_wallet(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_unfreeze_wallet(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_set_account_flag(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_clear_account_flag(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_get_fraud_metrics() TO authenticated;
