-- Final Production Hardening
-- Referral settings extension, server-side fee enforcement, notification enterprise upgrade

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 1: Extended Referral Settings
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.referral_settings
  ADD COLUMN IF NOT EXISTS referral_system_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS investment_rewards_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS referral_commission_rate NUMERIC(5,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS min_investment_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_commission NUMERIC(18,4) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_referral_levels INTEGER NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS referral_expiration_days INTEGER,
  ADD COLUMN IF NOT EXISTS referral_expiration_rules JSONB NOT NULL DEFAULT '{}'::JSONB,
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 2: Extended Fee Configuration
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.fees
  ADD COLUMN IF NOT EXISTS min_fee NUMERIC(15,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_fee NUMERIC(15,4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES auth.users(id);

-- Expand fee categories
ALTER TABLE public.fees DROP CONSTRAINT IF EXISTS fees_category_check;
ALTER TABLE public.fees ADD CONSTRAINT fees_category_check
  CHECK (category = ANY (ARRAY[
    'deposit', 'withdraw', 'investment', 'transfer', 'loan', 'agent',
    'marketplace', 'qr_receive'
  ]));

-- Seed default fee rows if missing
INSERT INTO public.fees (label, value, percentage, fixed_amount, category, is_active)
SELECT 'رسوم الإيداع', '1.5%', 1.5, 0, 'deposit', TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.fees WHERE category = 'deposit' AND is_active = TRUE);

INSERT INTO public.fees (label, value, percentage, fixed_amount, category, is_active)
SELECT 'رسوم السحب', '1.0%', 1.0, 0, 'withdraw', TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.fees WHERE category = 'withdraw' AND is_active = TRUE);

INSERT INTO public.fees (label, value, percentage, fixed_amount, category, is_active)
SELECT 'رسوم التحويل', '0.5%', 0.5, 0, 'transfer', TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.fees WHERE category = 'transfer' AND is_active = TRUE);

INSERT INTO public.fees (label, value, percentage, fixed_amount, category, is_active)
SELECT 'رسوم استلام QR', '0.25%', 0.25, 0, 'qr_receive', TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.fees WHERE category = 'qr_receive' AND is_active = TRUE);

INSERT INTO public.fees (label, value, percentage, fixed_amount, category, is_active)
SELECT 'رسوم السوق', '0%', 0, 0, 'marketplace', TRUE
WHERE NOT EXISTS (SELECT 1 FROM public.fees WHERE category = 'marketplace' AND is_active = TRUE);

-- ══════════════════════════════════════════════════════════════════════════════
-- Server-side fee calculation (single source of truth)
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_calculate_fee(
  p_category TEXT,
  p_amount NUMERIC
) RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_fee NUMERIC := 0;
  v_part NUMERIC;
  v_row RECORD;
  v_cat TEXT := LOWER(TRIM(COALESCE(p_category, '')));
  v_amt NUMERIC := COALESCE(p_amount, 0);
BEGIN
  IF v_amt <= 0 THEN
    RETURN jsonb_build_object(
      'gross_amount', v_amt, 'fee', 0, 'net_amount', v_amt,
      'wallet_deduction', v_amt, 'category', v_cat
    );
  END IF;

  FOR v_row IN
    SELECT percentage, fixed_amount, min_fee, max_fee
    FROM fees
    WHERE LOWER(category) = v_cat AND is_active = TRUE
  LOOP
    v_part := (v_amt * COALESCE(v_row.percentage, 0) / 100.0) + COALESCE(v_row.fixed_amount, 0);
    IF COALESCE(v_row.min_fee, 0) > 0 AND v_part < v_row.min_fee THEN
      v_part := v_row.min_fee;
    END IF;
    IF COALESCE(v_row.max_fee, 0) > 0 AND v_part > v_row.max_fee THEN
      v_part := v_row.max_fee;
    END IF;
    v_fee := v_fee + GREATEST(v_part, 0);
  END LOOP;

  v_fee := ROUND(v_fee, 4);

  RETURN jsonb_build_object(
    'gross_amount', v_amt,
    'fee', v_fee,
    'net_amount', ROUND(v_amt - v_fee, 4),
    'wallet_deduction', ROUND(v_amt + v_fee, 4),
    'category', v_cat
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_calculate_fee(TEXT, NUMERIC) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_preview_fee(
  p_category TEXT,
  p_amount NUMERIC
) RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT fn_calculate_fee(p_category, p_amount);
$$;

GRANT EXECUTE ON FUNCTION public.fn_preview_fee(TEXT, NUMERIC) TO authenticated;

-- ══════════════════════════════════════════════════════════════════════════════
-- Referral settings RPCs with audit
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_get_referral_settings()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_row referral_settings%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM referral_settings WHERE id = 'default';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Settings not found');
  END IF;
  RETURN jsonb_build_object('success', TRUE, 'settings', to_jsonb(v_row));
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_referral_settings() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_update_referral_settings(p_settings JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_old referral_settings%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_old FROM referral_settings WHERE id = 'default' FOR UPDATE;

  UPDATE referral_settings SET
    new_user_usd_reward = COALESCE((p_settings->>'new_user_usd_reward')::NUMERIC, new_user_usd_reward),
    new_user_ksp_reward = COALESCE((p_settings->>'new_user_ksp_reward')::INTEGER, new_user_ksp_reward),
    referrer_usd_reward = COALESCE((p_settings->>'referrer_usd_reward')::NUMERIC, referrer_usd_reward),
    referrer_ksp_reward = COALESCE((p_settings->>'referrer_ksp_reward')::INTEGER, referrer_ksp_reward),
    investment_commission_rate = COALESCE((p_settings->>'investment_commission_rate')::NUMERIC, investment_commission_rate),
    referral_commission_rate = COALESCE((p_settings->>'referral_commission_rate')::NUMERIC, referral_commission_rate),
    registration_rewards_enabled = COALESCE((p_settings->>'registration_rewards_enabled')::BOOLEAN, registration_rewards_enabled),
    referral_system_enabled = COALESCE((p_settings->>'referral_system_enabled')::BOOLEAN, referral_system_enabled),
    investment_rewards_enabled = COALESCE((p_settings->>'investment_rewards_enabled')::BOOLEAN, investment_rewards_enabled),
    min_investment_amount = COALESCE((p_settings->>'min_investment_amount')::NUMERIC, min_investment_amount),
    max_commission = COALESCE((p_settings->>'max_commission')::NUMERIC, max_commission),
    max_referral_levels = COALESCE((p_settings->>'max_referral_levels')::INTEGER, max_referral_levels),
    referral_expiration_days = CASE
      WHEN p_settings ? 'referral_expiration_days' THEN (p_settings->>'referral_expiration_days')::INTEGER
      ELSE referral_expiration_days
    END,
    referral_expiration_rules = COALESCE(p_settings->'referral_expiration_rules', referral_expiration_rules),
    updated_at = NOW(),
    updated_by = v_admin
  WHERE id = 'default';

  INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
  VALUES (
    v_admin, 'update_referral_settings',
    jsonb_build_object('old', to_jsonb(v_old), 'new', p_settings),
    'referral_settings', 'success', 'default', 'referral_settings'
  );

  RETURN jsonb_build_object('success', TRUE, 'message', 'Referral settings updated');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_update_referral_settings(JSONB) TO authenticated;

-- Fee update RPC with audit
CREATE OR REPLACE FUNCTION public.fn_update_fee_config(
  p_fee_id UUID,
  p_label TEXT DEFAULT NULL,
  p_percentage NUMERIC DEFAULT NULL,
  p_fixed_amount NUMERIC DEFAULT NULL,
  p_min_fee NUMERIC DEFAULT NULL,
  p_max_fee NUMERIC DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_old fees%ROWTYPE;
  v_display TEXT;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_old FROM fees WHERE id = p_fee_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Fee not found');
  END IF;

  UPDATE fees SET
    label = COALESCE(p_label, label),
    percentage = COALESCE(p_percentage, percentage),
    fixed_amount = COALESCE(p_fixed_amount, fixed_amount),
    min_fee = COALESCE(p_min_fee, min_fee),
    max_fee = COALESCE(p_max_fee, max_fee),
    is_active = COALESCE(p_is_active, is_active),
    updated_at = NOW(),
    updated_by = v_admin
  WHERE id = p_fee_id
  RETURNING * INTO v_old;

  v_display := CASE
    WHEN COALESCE(v_old.percentage, 0) > 0 AND COALESCE(v_old.fixed_amount, 0) > 0
      THEN v_old.percentage || '% + $' || v_old.fixed_amount
    WHEN COALESCE(v_old.percentage, 0) > 0 THEN v_old.percentage || '%'
    WHEN COALESCE(v_old.fixed_amount, 0) > 0 THEN '$' || v_old.fixed_amount
    ELSE '0'
  END;

  UPDATE fees SET value = v_display WHERE id = p_fee_id;

  INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
  VALUES (
    v_admin, 'update_fee_config',
    jsonb_build_object('fee_id', p_fee_id, 'label', v_old.label, 'value', v_display),
    'fees', 'success', p_fee_id::TEXT, 'fees'
  );

  RETURN jsonb_build_object('success', TRUE, 'fee', to_jsonb(v_old));
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_update_fee_config(UUID, TEXT, NUMERIC, NUMERIC, NUMERIC, NUMERIC, BOOLEAN) TO authenticated;

-- ══════════════════════════════════════════════════════════════════════════════
-- Update process_referral_commission to respect settings toggles
-- Must DROP first: Postgres forbids renaming parameters via CREATE OR REPLACE
-- ══════════════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.process_referral_commission(uuid, numeric, text);
DROP FUNCTION IF EXISTS public.process_referral_commission(uuid, numeric, text, text);

CREATE OR REPLACE FUNCTION public.process_referral_commission(
  p_investor_id UUID,
  p_investment_amount NUMERIC,
  p_investment_id TEXT DEFAULT NULL,
  p_plan_name TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_referrer_id UUID;
  v_rate NUMERIC;
  v_commission NUMERIC;
  v_wallet_id UUID;
  v_investor_name TEXT;
  v_settings referral_settings%ROWTYPE;
  v_investment_key TEXT;
BEGIN
  SELECT * INTO v_settings FROM referral_settings WHERE id = 'default';
  IF NOT FOUND OR NOT v_settings.referral_system_enabled OR NOT v_settings.investment_rewards_enabled THEN
    RETURN jsonb_build_object('success', TRUE, 'message', 'Investment rewards disabled');
  END IF;

  IF p_investment_amount < COALESCE(v_settings.min_investment_amount, 0) THEN
    RETURN jsonb_build_object('success', TRUE, 'message', 'Below minimum investment for commission');
  END IF;

  SELECT referred_by INTO v_referrer_id FROM profiles WHERE id = p_investor_id;
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'No referrer');
  END IF;

  v_investment_key := COALESCE(
    p_investment_id,
    'manual:' || p_investor_id::TEXT || ':' || p_investment_amount::TEXT
  );

  IF EXISTS (
    SELECT 1 FROM referral_earnings
    WHERE investor_id = p_investor_id AND investment_id = v_investment_key
  ) THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Already processed');
  END IF;

  v_rate := COALESCE(v_settings.investment_commission_rate, 0.02);
  v_commission := ROUND(p_investment_amount * v_rate, 2);

  IF v_settings.max_commission > 0 AND v_commission > v_settings.max_commission THEN
    v_commission := v_settings.max_commission;
  END IF;

  IF v_commission <= 0 THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Zero commission');
  END IF;

  SELECT full_name INTO v_investor_name FROM profiles WHERE id = p_investor_id;

  SELECT id INTO v_wallet_id FROM wallets
  WHERE user_id = v_referrer_id AND currency = 'USD' FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    INSERT INTO wallets (user_id, currency, available_balance)
    VALUES (v_referrer_id, 'USD', v_commission)
    RETURNING id INTO v_wallet_id;
  ELSE
    UPDATE wallets SET available_balance = available_balance + v_commission, updated_at = NOW()
    WHERE id = v_wallet_id;
  END IF;

  INSERT INTO referral_earnings (
    referrer_id, investor_id, investment_amount, commission_amount,
    commission_rate, investment_id
  ) VALUES (
    v_referrer_id, p_investor_id, p_investment_amount, v_commission,
    v_rate, v_investment_key
  );

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id)
  VALUES (
    v_referrer_id, v_wallet_id, 'reward', v_commission, 'completed',
    'عمولة إحالة من استثمار ' || COALESCE(v_investor_name, 'مستخدم'),
    p_investor_id
  );

  PERFORM fn_create_notification(
    v_referrer_id,
    'عمولة إحالة 💰',
    COALESCE(v_investor_name, 'مستخدم') || ' استثمر $' || p_investment_amount::TEXT ||
      CASE WHEN p_plan_name IS NOT NULL THEN ' في خطة ' || p_plan_name ELSE '' END ||
      '. ربحت $' || v_commission::TEXT || ' عمولة إحالة.',
    'referral_commission', 'referral', v_investment_key, '/referrals',
    'user', 'normal'
  );

  RETURN jsonb_build_object('success', TRUE, 'commission', v_commission);
END;
$$;

GRANT EXECUTE ON FUNCTION public.process_referral_commission(uuid, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_referral_commission(uuid, numeric, text, text) TO service_role;

-- ══════════════════════════════════════════════════════════════════════════════
-- Financial RPCs with server-side fee enforcement
-- ══════════════════════════════════════════════════════════════════════════════

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
  IF p_amount < 10 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Minimum deposit is $10');
  END IF;

  v_fee_info := fn_calculate_fee('deposit', p_amount);
  v_fee := (v_fee_info->>'fee')::NUMERIC;

  SELECT id INTO v_wallet_id FROM wallets WHERE user_id = v_user_id LIMIT 1;
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
  IF p_amount < 10 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Minimum withdrawal is $10');
  END IF;

  v_fee_info := fn_calculate_fee('withdraw', p_amount);
  v_fee := (v_fee_info->>'fee')::NUMERIC;
  v_total_deduction := p_amount + v_fee;

  SELECT id, available_balance INTO v_wallet_id, v_available
  FROM wallets WHERE user_id = v_user_id LIMIT 1;

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
    RETURN json_build_object('success', FALSE, 'error', 'Agent not found');
  END IF;

  SELECT full_name INTO v_user_name FROM profiles WHERE id = v_user_id;

  SELECT id INTO v_transaction_id
  FROM transactions WHERE idempotency_key = p_idempotency_key LIMIT 1;
  IF v_transaction_id IS NOT NULL THEN
    RETURN json_build_object('success', TRUE, 'transaction_id', v_transaction_id, 'idempotent', TRUE);
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key
  ) VALUES (
    v_user_id, v_wallet_id, 'withdrawal', p_amount, v_fee, p_currency,
    'pending', p_agent_id,
    'سحب عبر وكيل: ' || v_agent_name,
    p_idempotency_key
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets SET
    available_balance = available_balance - v_total_deduction,
    pending_balance = pending_balance + p_amount
  WHERE id = v_wallet_id;

  PERFORM fn_create_notification(
    v_agent_user_id,
    'طلب سحب جديد',
    COALESCE(v_user_name, 'مستخدم') || ' قدم طلب سحب بمبلغ $' || p_amount || ' USD',
    'agent_withdrawal_pending', 'transaction', v_transaction_id::TEXT, '/agent-transactions', 'agent', 'high'
  );

  PERFORM fn_log_financial_audit(
    v_user_id, 'user', 'withdrawal_request', v_transaction_id,
    NULL, 'pending', p_amount,
    jsonb_build_object('fee', v_fee, 'total_deduction', v_total_deduction)
  );

  RETURN json_build_object(
    'success', TRUE, 'transaction_id', v_transaction_id,
    'fee', v_fee, 'total_deduction', v_total_deduction
  );
END;
$$;

-- Transfer with fee enforcement (extends QA migration version)
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
      v_receiver_id, 'تحويل إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
      p_idempotency_key, v_sender_wallet.available_balance - v_total_debit
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
      jsonb_build_object('receiver_id', v_receiver_id, 'fee', v_fee, 'transfer_in_id', v_tx_in_id)
    );

    PERFORM fn_create_notification(
      v_receiver_id,
      'تحويل واردة 💸',
      COALESCE(v_sender_name, 'مستخدم') || ' حوّل لك $' || p_amount,
      'transfer_received', 'transaction', v_tx_in_id::TEXT, '/wallet', 'user', 'normal'
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

-- ══════════════════════════════════════════════════════════════════════════════
-- PART 4: Notification Enterprise Upgrade
-- ══════════════════════════════════════════════════════════════════════════════

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS sound_type TEXT DEFAULT 'general';

CREATE TABLE IF NOT EXISTS public.notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID REFERENCES public.notifications(id) ON DELETE SET NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  channel TEXT,
  details JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_logs_notif ON public.notification_logs(notification_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_logs_user ON public.notification_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_admin_unread
  ON public.notifications(role_target, read_at, sent_at DESC)
  WHERE deleted_at IS NULL;

ALTER TABLE public.notification_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins read notification logs" ON public.notification_logs;
CREATE POLICY "Admins read notification logs"
  ON public.notification_logs FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS "System inserts notification logs" ON public.notification_logs;
CREATE POLICY "System inserts notification logs"
  ON public.notification_logs FOR INSERT TO authenticated
  WITH CHECK (TRUE);

-- Log helper
CREATE OR REPLACE FUNCTION public.fn_log_notification_event(
  p_notification_id UUID,
  p_user_id UUID,
  p_event_type TEXT,
  p_channel TEXT DEFAULT NULL,
  p_details JSONB DEFAULT '{}'::JSONB
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  INSERT INTO notification_logs (notification_id, user_id, event_type, channel, details)
  VALUES (p_notification_id, p_user_id, p_event_type, p_channel, COALESCE(p_details, '{}'::JSONB));
END;
$$;

-- Enhanced fn_create_notification with logging + category mapping
CREATE OR REPLACE FUNCTION public.fn_create_notification(
  p_user_id UUID,
  p_title TEXT,
  p_body TEXT,
  p_type TEXT DEFAULT 'system',
  p_entity_type TEXT DEFAULT NULL,
  p_entity_id TEXT DEFAULT NULL,
  p_deep_link TEXT DEFAULT NULL,
  p_role_target TEXT DEFAULT 'user',
  p_priority TEXT DEFAULT 'normal'
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_notif_id UUID;
  v_category TEXT;
  v_sound TEXT;
BEGIN
  v_category := CASE
    WHEN p_type ILIKE '%deposit%' OR p_type ILIKE '%withdraw%' OR p_type ILIKE '%transfer%' THEN 'financial'
    WHEN p_type ILIKE '%referral%' THEN 'referral'
    WHEN p_type ILIKE '%investment%' THEN 'investment'
    WHEN p_type ILIKE '%marketplace%' THEN 'marketplace'
    WHEN p_type ILIKE '%kyc%' OR p_type ILIKE '%verified%' THEN 'kyc'
    WHEN p_type ILIKE '%loan%' THEN 'loans'
    WHEN p_type ILIKE '%chat%' OR p_type ILIKE '%message%' THEN 'chat'
    WHEN p_type ILIKE '%wheel%' OR p_type ILIKE '%reward%' THEN 'rewards'
    WHEN p_type ILIKE '%security%' OR p_type ILIKE '%frozen%' THEN 'security'
    WHEN p_type ILIKE '%admin%' THEN 'system'
    ELSE 'system'
  END;

  v_sound := CASE v_category
    WHEN 'financial' THEN 'financial_success'
    WHEN 'security' THEN 'security'
    WHEN 'chat' THEN 'chat'
    WHEN 'kyc' THEN 'approval'
    ELSE 'general'
  END;

  INSERT INTO public.notifications (
    user_id, title, message, type, entity_type, entity_id,
    deep_link, role_target, priority, status, category, sound_type
  ) VALUES (
    p_user_id, p_title, p_body, p_type, p_entity_type, p_entity_id,
    p_deep_link, p_role_target, p_priority, 'sent', v_category, v_sound
  )
  RETURNING id INTO v_notif_id;

  PERFORM fn_log_notification_event(v_notif_id, p_user_id, 'created', 'database', jsonb_build_object('type', p_type));

  RETURN v_notif_id;
END;
$$;

-- Admin unread count
CREATE OR REPLACE FUNCTION public.fn_admin_unread_notification_count()
RETURNS INTEGER
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT COUNT(*)::INTEGER
  FROM notifications
  WHERE role_target = 'admin'
    AND read_at IS NULL
    AND deleted_at IS NULL
    AND is_archived = FALSE
    AND (user_id = auth.uid() OR user_id IN (SELECT id FROM admin_profiles WHERE is_active = TRUE));
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_unread_notification_count() TO authenticated;

-- Admin mark read
CREATE OR REPLACE FUNCTION public.fn_admin_mark_notification_read(p_notification_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  UPDATE notifications SET read_at = NOW(), status = 'read'
  WHERE id = p_notification_id AND deleted_at IS NULL;

  PERFORM fn_log_notification_event(p_notification_id, auth.uid(), 'read', 'app', '{}'::JSONB);

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_mark_notification_read(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_admin_mark_all_notifications_read()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  UPDATE notifications SET read_at = NOW(), status = 'read'
  WHERE role_target = 'admin' AND read_at IS NULL AND deleted_at IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN jsonb_build_object('success', TRUE, 'count', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_mark_all_notifications_read() TO authenticated;

-- Notification analytics
CREATE OR REPLACE FUNCTION public.fn_admin_notification_analytics()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_total INTEGER;
  v_unread INTEGER;
  v_read INTEGER;
  v_failed INTEGER;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT COUNT(*) INTO v_total FROM notifications WHERE role_target = 'admin' AND deleted_at IS NULL;
  SELECT COUNT(*) INTO v_unread FROM notifications WHERE role_target = 'admin' AND read_at IS NULL AND deleted_at IS NULL;
  SELECT COUNT(*) INTO v_read FROM notifications WHERE role_target = 'admin' AND read_at IS NOT NULL AND deleted_at IS NULL;
  SELECT COUNT(*) INTO v_failed FROM notifications WHERE role_target = 'admin' AND status = 'failed';

  RETURN jsonb_build_object(
    'success', TRUE,
    'total', v_total,
    'unread', v_unread,
    'read', v_read,
    'failed', v_failed,
    'delivery_rate', CASE WHEN v_total > 0 THEN ROUND((v_total - v_failed)::NUMERIC / v_total * 100, 1) ELSE 100 END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_notification_analytics() TO authenticated;

-- Fix KYC trigger with user names
CREATE OR REPLACE FUNCTION public.fn_trigger_kyc_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_ids UUID[];
  v_user_name TEXT := COALESCE(NEW.full_name, 'مستخدم');
BEGIN
  IF NEW.kyc_status = 'verified' AND OLD.kyc_status != 'verified' THEN
    PERFORM public.fn_create_notification(
      NEW.id,
      'تم توثيق حسابك ✅',
      'تم التحقق من هوية حساب ' || v_user_name || ' بنجاح.',
      'kyc_approved', 'profile', NEW.id::TEXT, '/profile'
    );
  END IF;

  IF NEW.kyc_status = 'rejected' AND OLD.kyc_status != 'rejected' THEN
    PERFORM public.fn_create_notification(
      NEW.id,
      'تم رفض التوثيق ❌',
      'تم رفض طلب KYC لـ ' || v_user_name || '.',
      'kyc_rejected', 'profile', NEW.id::TEXT, '/profile'
    );
  END IF;

  IF NEW.kyc_status = 'pending' AND OLD.kyc_status != 'pending' THEN
    SELECT ARRAY_AGG(id) INTO v_admin_ids FROM admin_profiles WHERE is_active = TRUE;
    IF v_admin_ids IS NOT NULL THEN
      PERFORM public.fn_create_bulk_notification(
        v_admin_ids,
        'طلب توثيق جديد 📋',
        'طلب KYC من ' || v_user_name || ' بانتظار المراجعة.',
        'admin_kyc_pending', 'profile', NEW.id::TEXT, '/kyc', 'admin', 'high'
      );
    END IF;
  END IF;

  IF NEW.status = 'blocked' AND OLD.status != 'blocked' THEN
    PERFORM public.fn_create_notification(
      NEW.id, 'تم تجميد حسابك ⛔',
      'تم تجميد حساب ' || v_user_name || '. يرجى التواصل مع الدعم.',
      'account_frozen', 'profile', NEW.id::TEXT, '/support', 'user', 'critical'
    );
  END IF;

  IF NEW.role = 'agent' AND OLD.role != 'agent' THEN
    PERFORM public.fn_create_notification(
      NEW.id, 'مبروك! تمت ترقيتك إلى وكيل 🎉',
      'تم ترقية حساب ' || v_user_name || ' إلى وكيل كاسبي.',
      'role_upgraded', 'profile', NEW.id::TEXT, '/agent-dashboard'
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Fix transaction notification trigger with user names
CREATE OR REPLACE FUNCTION public.fn_trigger_transaction_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_ids UUID[];
  v_agent_id UUID;
  v_user_name TEXT;
  v_counterpart_name TEXT;
BEGIN
  SELECT full_name INTO v_user_name FROM profiles WHERE id = NEW.user_id;

  IF NEW.type = 'deposit' AND NEW.status = 'approved' AND (OLD IS NULL OR OLD.status != 'approved') THEN
    PERFORM fn_create_notification(
      NEW.user_id, 'تمت الموافقة على الإيداع ✅',
      'تم إيداع ' || NEW.amount || ' في محفظة ' || COALESCE(v_user_name, 'مستخدم') || '.',
      'deposit_approved', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'deposit' AND NEW.status = 'rejected' AND (OLD IS NULL OR OLD.status != 'rejected') THEN
    PERFORM fn_create_notification(
      NEW.user_id, 'تم رفض الإيداع ❌',
      'تم رفض طلب إيداع ' || COALESCE(v_user_name, 'مستخدم') || ': ' || COALESCE(NEW.rejection_reason, ''),
      'deposit_rejected', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'withdrawal' AND NEW.status = 'completed' AND (OLD IS NULL OR OLD.status != 'completed') THEN
    PERFORM fn_create_notification(
      NEW.user_id, 'تم تنفيذ السحب ✅',
      COALESCE(v_user_name, 'مستخدم') || ' — تم سحب ' || NEW.amount || ' بنجاح.',
      'withdrawal_completed', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'withdrawal' AND NEW.status = 'rejected' AND (OLD IS NULL OR OLD.status != 'rejected') THEN
    PERFORM fn_create_notification(
      NEW.user_id, 'تم رفض السحب ❌',
      'تم رفض طلب سحب ' || COALESCE(v_user_name, 'مستخدم'),
      'withdrawal_rejected', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF NEW.type = 'transfer_in' AND NEW.status = 'completed' AND TG_OP = 'INSERT' THEN
    SELECT full_name INTO v_counterpart_name FROM profiles WHERE id = NEW.counterpart_user_id;
    PERFORM fn_create_notification(
      NEW.user_id, 'تحويل واردة 💸',
      COALESCE(v_counterpart_name, 'مستخدم') || ' حوّل لك $' || NEW.amount,
      'transfer_received', 'transaction', NEW.id::TEXT, '/wallet'
    );
  END IF;

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    SELECT ARRAY_AGG(id) INTO v_admin_ids FROM admin_profiles WHERE is_active = TRUE;
    IF v_admin_ids IS NOT NULL THEN
      IF NEW.type = 'deposit' THEN
        PERFORM fn_create_bulk_notification(
          v_admin_ids, 'إيداع جديد بانتظار المراجعة 📥',
          COALESCE(v_user_name, 'مستخدم') || ' قدم طلب إيداع بمبلغ $' || NEW.amount,
          'admin_deposit_pending', 'transaction', NEW.id::TEXT, '/transactions', 'admin', 'high'
        );
      ELSIF NEW.type = 'withdrawal' THEN
        PERFORM fn_create_bulk_notification(
          v_admin_ids, 'سحب جديد بانتظار المراجعة 📤',
          COALESCE(v_user_name, 'مستخدم') || ' قدم طلب سحب بمبلغ $' || NEW.amount,
          'admin_withdrawal_pending', 'transaction', NEW.id::TEXT, '/transactions', 'admin', 'high'
        );
      END IF;
    END IF;

    IF NEW.type = 'withdrawal' AND NEW.reference_id IS NOT NULL THEN
      BEGIN
        SELECT a.user_id INTO v_agent_id FROM agents a WHERE a.id = NEW.reference_id::UUID;
        IF v_agent_id IS NOT NULL THEN
          PERFORM fn_create_notification(
            v_agent_id, 'طلب سحب جديد مخصص لك 📤',
            COALESCE(v_user_name, 'مستخدم') || ' — سحب $' || NEW.amount || ' بانتظار التسليم.',
            'agent_withdrawal_pending', 'transaction', NEW.id::TEXT, '/agent-transactions', 'agent', 'high'
          );
        END IF;
      EXCEPTION WHEN OTHERS THEN NULL;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- Fix investment notification with user name
CREATE OR REPLACE FUNCTION public.fn_trigger_investment_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_ids UUID[];
  v_user_name TEXT;
BEGIN
  SELECT full_name INTO v_user_name FROM profiles WHERE id = NEW.user_id;

  IF TG_OP = 'INSERT' AND NEW.status = 'active' THEN
    PERFORM fn_create_notification(
      NEW.user_id, 'تم إنشاء الاستثمار 🚀',
      COALESCE(v_user_name, 'مستخدم') || ' استثمر ' || NEW.amount || ' USD',
      'investment_created', 'investment', NEW.id::TEXT, '/investments'
    );
  END IF;

  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
    SELECT ARRAY_AGG(id) INTO v_admin_ids FROM admin_profiles WHERE is_active = TRUE;
    IF v_admin_ids IS NOT NULL THEN
      PERFORM fn_create_bulk_notification(
        v_admin_ids, '📈 استثمار جديد بانتظار المراجعة',
        COALESCE(v_user_name, 'مستخدم') || ' استثمر ' || NEW.amount || ' USD',
        'admin_investment_pending', 'investment', NEW.id::TEXT, '/investments', 'admin', 'high'
      );
    END IF;
  END IF;

  IF NEW.status = 'matured' AND (OLD IS NULL OR OLD.status != 'matured') THEN
    PERFORM fn_create_notification(
      NEW.user_id, 'استثمارك نضج! 🎉',
      'استثمار ' || COALESCE(v_user_name, 'مستخدم') || ' بقيمة ' || NEW.amount || ' اكتمل.',
      'investment_matured', 'investment', NEW.id::TEXT, '/investments'
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Realtime for referral_settings and fees
ALTER TABLE public.referral_settings REPLICA IDENTITY FULL;
ALTER TABLE public.fees REPLICA IDENTITY FULL;
