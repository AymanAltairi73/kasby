-- ============================================================================
-- REFERRAL & FINANCIAL ENTERPRISE REMEDIATION
-- Root-cause fixes: idempotency, referral rewards, notifications, team analytics,
-- transaction details RPC, structured logging, realtime sync.
-- ============================================================================

-- ── 1. Referral configuration (single-row policy table) ──
CREATE TABLE IF NOT EXISTS public.referral_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  new_user_usd_reward NUMERIC(18,4) NOT NULL DEFAULT 0,
  new_user_ksp_reward INTEGER NOT NULL DEFAULT 100,
  referrer_usd_reward NUMERIC(18,4) NOT NULL DEFAULT 0,
  referrer_ksp_reward INTEGER NOT NULL DEFAULT 50,
  investment_commission_rate NUMERIC(5,4) NOT NULL DEFAULT 0.02,
  registration_rewards_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.referral_settings (id)
VALUES ('default')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.referral_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read referral settings" ON public.referral_settings;
CREATE POLICY "Anyone can read referral settings"
  ON public.referral_settings FOR SELECT TO authenticated USING (TRUE);

DROP POLICY IF EXISTS "Admins manage referral settings" ON public.referral_settings;
CREATE POLICY "Admins manage referral settings"
  ON public.referral_settings FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ── 2. Referral activity timeline ──
CREATE TABLE IF NOT EXISTS public.referral_activity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  member_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_referral_activity_referrer
  ON public.referral_activity(referrer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_referral_activity_member
  ON public.referral_activity(member_id, created_at DESC);

ALTER TABLE public.referral_activity REPLICA IDENTITY FULL;
ALTER TABLE public.referral_activity ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Referrers read own activity" ON public.referral_activity;
CREATE POLICY "Referrers read own activity"
  ON public.referral_activity FOR SELECT TO authenticated
  USING (referrer_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "System inserts referral activity" ON public.referral_activity;
CREATE POLICY "System inserts referral activity"
  ON public.referral_activity FOR INSERT TO authenticated
  WITH CHECK (TRUE);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public' AND tablename = 'referral_activity'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.referral_activity;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public' AND tablename = 'transactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
  END IF;
END $$;

-- ── 3. Idempotency ledger for KSP transfers and registration rewards ──
CREATE TABLE IF NOT EXISTS public.financial_idempotency_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  idempotency_key TEXT NOT NULL,
  operation_type TEXT NOT NULL,
  result_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, idempotency_key, operation_type)
);

CREATE INDEX IF NOT EXISTS idx_financial_idempotency_lookup
  ON public.financial_idempotency_keys(user_id, idempotency_key, operation_type);

ALTER TABLE public.financial_idempotency_keys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own idempotency keys" ON public.financial_idempotency_keys;
CREATE POLICY "Users read own idempotency keys"
  ON public.financial_idempotency_keys FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

-- ── 4. Registration reward idempotency guard ──
CREATE TABLE IF NOT EXISTS public.referral_registration_rewards (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  referrer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  new_user_usd NUMERIC(18,4) NOT NULL DEFAULT 0,
  new_user_ksp INTEGER NOT NULL DEFAULT 0,
  referrer_usd NUMERIC(18,4) NOT NULL DEFAULT 0,
  referrer_ksp INTEGER NOT NULL DEFAULT 0,
  processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 5. Helper: log referral activity + system log ──
CREATE OR REPLACE FUNCTION public.fn_log_referral_activity(
  p_referrer_id UUID,
  p_member_id UUID,
  p_event_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_metadata JSONB DEFAULT '{}'::JSONB
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF p_referrer_id IS NULL THEN RETURN NULL; END IF;

  INSERT INTO referral_activity (referrer_id, member_id, event_type, title, body, metadata)
  VALUES (p_referrer_id, p_member_id, p_event_type, p_title, p_body, COALESCE(p_metadata, '{}'::JSONB))
  RETURNING id INTO v_id;

  INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
  VALUES (
    COALESCE(p_member_id, p_referrer_id),
    'system',
    'referral_' || p_event_type,
    'referral',
    v_id::TEXT,
    jsonb_build_object(
      'referrer_id', p_referrer_id,
      'member_id', p_member_id,
      'event_type', p_event_type
    ) || COALESCE(p_metadata, '{}'::JSONB),
    'info'
  );

  RETURN v_id;
END;
$$;

-- ── 6. validate_referral_code RPC (missing from production) ──
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
  v_normalized := UPPER(REPLACE(TRIM(COALESCE(p_code, '')), '-', ''));

  IF v_normalized = '' OR v_normalized !~ '^K[A-Z0-9]{4,}$' THEN
    RETURN json_build_object('valid', FALSE, 'reason', 'invalid_format');
  END IF;

  SELECT id, referral_code, full_name, status
    INTO v_profile
    FROM profiles
    WHERE UPPER(REPLACE(referral_code, '-', '')) = v_normalized
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

GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon, authenticated;

-- ── 7. Process synchronized registration rewards ──
CREATE OR REPLACE FUNCTION public.process_registration_rewards(
  p_new_user_id UUID,
  p_referrer_id UUID
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_settings RECORD;
  v_new_user_name TEXT;
  v_referrer_name TEXT;
  v_referrer_code TEXT;
  v_new_wallet_id UUID;
  v_ref_wallet_id UUID;
BEGIN
  IF p_new_user_id IS NULL OR p_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Missing user or referrer');
  END IF;

  IF p_new_user_id = p_referrer_id THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Self referral blocked');
  END IF;

  IF EXISTS (SELECT 1 FROM referral_registration_rewards WHERE user_id = p_new_user_id) THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Already processed');
  END IF;

  SELECT * INTO v_settings FROM referral_settings WHERE id = 'default';
  IF NOT FOUND OR NOT v_settings.registration_rewards_enabled THEN
    RETURN jsonb_build_object('success', TRUE, 'message', 'Registration rewards disabled');
  END IF;

  SELECT full_name, referral_code INTO v_new_user_name, v_referrer_code
  FROM profiles WHERE id = p_new_user_id;

  SELECT full_name INTO v_referrer_name FROM profiles WHERE id = p_referrer_id;

  -- New user USD reward
  IF v_settings.new_user_usd_reward > 0 THEN
    SELECT id INTO v_new_wallet_id FROM wallets
    WHERE user_id = p_new_user_id AND currency = 'USD' FOR UPDATE;
    IF v_new_wallet_id IS NOT NULL THEN
      UPDATE wallets SET available_balance = available_balance + v_settings.new_user_usd_reward,
        updated_at = NOW()
      WHERE id = v_new_wallet_id;
      INSERT INTO transactions (user_id, wallet_id, type, amount, status, description)
      VALUES (p_new_user_id, v_new_wallet_id, 'reward', v_settings.new_user_usd_reward,
        'completed', 'مكافأة التسجيل عبر الإحالة');
    END IF;
  END IF;

  -- New user KSP reward
  IF v_settings.new_user_ksp_reward > 0 THEN
    PERFORM fn_credit_reward_ksp(
      p_new_user_id,
      v_settings.new_user_ksp_reward,
      'Referral registration bonus',
      'registration:' || p_new_user_id::TEXT
    );
  END IF;

  -- Referrer USD reward
  IF v_settings.referrer_usd_reward > 0 THEN
    SELECT id INTO v_ref_wallet_id FROM wallets
    WHERE user_id = p_referrer_id AND currency = 'USD' FOR UPDATE;
    IF v_ref_wallet_id IS NULL THEN
      INSERT INTO wallets (user_id, currency, available_balance)
      VALUES (p_referrer_id, 'USD', v_settings.referrer_usd_reward)
      RETURNING id INTO v_ref_wallet_id;
    ELSE
      UPDATE wallets SET available_balance = available_balance + v_settings.referrer_usd_reward,
        updated_at = NOW()
      WHERE id = v_ref_wallet_id;
    END IF;
    INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id)
    VALUES (p_referrer_id, v_ref_wallet_id, 'reward', v_settings.referrer_usd_reward,
      'completed', 'مكافأة إحالة عضو جديد', p_new_user_id);
  END IF;

  -- Referrer KSP reward
  IF v_settings.referrer_ksp_reward > 0 THEN
    PERFORM fn_credit_reward_ksp(
      p_referrer_id,
      v_settings.referrer_ksp_reward,
      'New referral registration bonus',
      'registration:' || p_new_user_id::TEXT
    );
  END IF;

  INSERT INTO referral_registration_rewards (
    user_id, referrer_id, new_user_usd, new_user_ksp, referrer_usd, referrer_ksp
  ) VALUES (
    p_new_user_id, p_referrer_id,
    v_settings.new_user_usd_reward, v_settings.new_user_ksp_reward,
    v_settings.referrer_usd_reward, v_settings.referrer_ksp_reward
  );

  -- Notify referrer (push + in-app)
  PERFORM fn_create_notification(
    p_referrer_id,
    'عضو جديد في فريقك',
    COALESCE(v_new_user_name, 'مستخدم') || ' انضم إلى Kasby باستخدام رمز الإحالة الخاص بك.',
    'referral_bonus', 'referral', p_new_user_id::TEXT, '/my-team', 'user', 'normal'
  );

  -- Notify new user
  PERFORM fn_create_notification(
    p_new_user_id,
    'مرحباً بك في Kasby',
    'لقد انضممت بنجاح باستخدام رمز إحالة ' || COALESCE(v_referrer_name, 'صديق') ||
      '. رمزك: ' || COALESCE(v_referrer_code, '') ||
      CASE WHEN v_settings.new_user_usd_reward > 0
        THEN '. مكافأتك: $' || v_settings.new_user_usd_reward::TEXT
        ELSE '' END ||
      CASE WHEN v_settings.new_user_ksp_reward > 0
        THEN ' + ' || v_settings.new_user_ksp_reward::TEXT || ' KSP'
        ELSE '' END,
    'referral_bonus', 'referral', p_referrer_id::TEXT, '/my-team', 'user', 'normal'
  );

  PERFORM fn_log_referral_activity(
    p_referrer_id, p_new_user_id, 'member_joined',
    COALESCE(v_new_user_name, 'عضو') || ' انضم عبر رمز الإحالة',
    'تسجيل جديد في شبكة الإحالة',
    jsonb_build_object(
      'new_user_ksp', v_settings.new_user_ksp_reward,
      'new_user_usd', v_settings.new_user_usd_reward,
      'referrer_ksp', v_settings.referrer_ksp_reward,
      'referrer_usd', v_settings.referrer_usd_reward
    )
  );

  RETURN jsonb_build_object('success', TRUE);
END;
$$;

-- ── 8. Enhanced handle_new_user with normalized lookup + rewards ──
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_referred_by_id UUID := NULL;
  v_referral_code  TEXT;
  v_input_code     TEXT;
BEGIN
  v_input_code := NEW.raw_user_meta_data ->> 'referred_by_code';

  IF v_input_code IS NOT NULL AND TRIM(v_input_code) != '' THEN
    SELECT id INTO v_referred_by_id
    FROM profiles
    WHERE UPPER(REPLACE(referral_code, '-', '')) = UPPER(REPLACE(TRIM(v_input_code), '-', ''))
      AND status NOT IN ('blocked', 'suspended')
    LIMIT 1;

    IF v_referred_by_id = NEW.id THEN
      v_referred_by_id := NULL;
    END IF;
  END IF;

  v_referral_code := 'K' || nextval('referral_code_seq')::TEXT;

  INSERT INTO profiles (
    id, full_name, email, phone, country_code, referral_code, referred_by
  ) VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''), 'مستخدم جديد'),
    COALESCE(NULLIF(NEW.email, ''), NEW.raw_user_meta_data ->> 'email', ''),
    COALESCE(NULLIF(NEW.phone, ''), NEW.raw_user_meta_data ->> 'phone'),
    COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
    v_referral_code,
    v_referred_by_id
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    country_code = EXCLUDED.country_code,
    referral_code = COALESCE(profiles.referral_code, EXCLUDED.referral_code),
    referred_by = COALESCE(profiles.referred_by, EXCLUDED.referred_by);

  INSERT INTO wallets (user_id, currency) VALUES (NEW.id, 'USD')
  ON CONFLICT (user_id, currency) DO NOTHING;

  INSERT INTO user_points (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  IF v_referred_by_id IS NOT NULL THEN
    PERFORM process_registration_rewards(NEW.id, v_referred_by_id);
  END IF;

  INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
  VALUES (
    NEW.id, 'user', 'user_registered', 'profile', NEW.id::TEXT,
    jsonb_build_object(
      'referred_by', v_referred_by_id,
      'referral_code', v_referral_code
    ),
    'info'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Ensure trigger exists on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 9. Enhanced process_referral_commission with rich notifications ──
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
  v_commission NUMERIC;
  v_rate NUMERIC;
  v_investor_name TEXT;
  v_wallet_id UUID;
  v_investment_key TEXT;
BEGIN
  SELECT referred_by INTO v_referrer_id FROM profiles WHERE id = p_investor_id;
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'No referrer');
  END IF;

  v_investment_key := COALESCE(p_investment_id, 'manual:' || p_investor_id::TEXT || ':' || p_investment_amount::TEXT);

  IF EXISTS (
    SELECT 1 FROM referral_earnings
    WHERE investor_id = p_investor_id AND investment_id = v_investment_key
  ) THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Already processed');
  END IF;

  SELECT investment_commission_rate INTO v_rate FROM referral_settings WHERE id = 'default';
  v_rate := COALESCE(v_rate, 0.02);
  v_commission := ROUND(p_investment_amount * v_rate, 2);

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
    'عمولة إحالة من استثمار ' || COALESCE(v_investor_name, 'عضو'),
    p_investor_id
  );

  PERFORM fn_create_notification(
    v_referrer_id,
    'مكافأة إحالة من استثمار',
    COALESCE(v_investor_name, 'عضو') || ' استثمر $' || p_investment_amount::TEXT ||
      CASE WHEN p_plan_name IS NOT NULL THEN ' في خطة ' || p_plan_name ELSE '' END ||
      '. ربحت $' || v_commission::TEXT || ' عمولة إحالة.',
    'referral_bonus', 'referral', v_investment_key, '/referral-analytics', 'user', 'high'
  );

  PERFORM fn_log_referral_activity(
    v_referrer_id, p_investor_id, 'investment_commission',
    COALESCE(v_investor_name, 'عضو') || ' استثمر $' || p_investment_amount::TEXT,
    'ربحت $' || v_commission::TEXT || ' عمولة إحالة',
    jsonb_build_object(
      'investment_amount', p_investment_amount,
      'commission', v_commission,
      'plan_name', p_plan_name,
      'investment_id', v_investment_key
    )
  );

  INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
  VALUES (
    p_investor_id, 'system', 'referral_commission_paid', 'referral',
    v_investment_key,
    jsonb_build_object(
      'referrer_id', v_referrer_id,
      'amount', v_commission,
      'investment_amount', p_investment_amount
    ),
    'info'
  );

  RETURN jsonb_build_object('success', TRUE, 'commission', v_commission);
END;
$$;

-- ── 10. fn_transfer_ksp with idempotency ──
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
  v_sender_id UUID := auth.uid();
  v_receiver_id UUID;
  v_receiver_name TEXT;
  v_sender_name TEXT;
  v_deduct JSONB;
  v_tx_id UUID;
  v_cached JSONB;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid amount');
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

  SELECT id, full_name INTO v_receiver_id, v_receiver_name
  FROM profiles
  WHERE UPPER(referral_code) = UPPER(REPLACE(p_receiver_referral_code, '-', ''))
  LIMIT 1;

  IF v_receiver_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Receiver not found');
  END IF;

  IF v_receiver_id = v_sender_id THEN
    RETURN json_build_object('success', FALSE, 'error', 'Cannot transfer to yourself');
  END IF;

  SELECT full_name INTO v_sender_name FROM profiles WHERE id = v_sender_id;

  v_deduct := fn_deduct_effective_ksp(
    v_sender_id, p_amount,
    'KSP transfer to ' || COALESCE(v_receiver_name, 'user'),
    p_idempotency_key
  );

  IF COALESCE((v_deduct->>'success')::BOOLEAN, FALSE) IS NOT TRUE THEN
    RETURN json_build_object(
      'success', FALSE,
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
    'تم تحويل ' || p_amount::TEXT || ' KSP إليك من ' || COALESCE(v_sender_name, 'مستخدم'),
    'transfer_received', 'transaction', v_tx_id::TEXT, '/wallet', 'user', 'normal'
  );

  PERFORM fn_create_notification(
    v_sender_id, 'تم إرسال النقاط',
    'تم تحويل ' || p_amount::TEXT || ' KSP إلى ' || COALESCE(v_receiver_name, 'مستخدم'),
    'transfer_sent', 'transaction', v_tx_id::TEXT, '/wallet', 'user', 'normal'
  );

  IF p_idempotency_key IS NOT NULL THEN
    INSERT INTO financial_idempotency_keys (user_id, idempotency_key, operation_type, result_payload)
    VALUES (
      v_sender_id, p_idempotency_key, 'ksp_transfer',
      jsonb_build_object(
        'success', TRUE,
        'transaction_id', v_tx_id,
        'receiver_name', v_receiver_name,
        'message', 'KSP transfer completed'
      )
    )
    ON CONFLICT (user_id, idempotency_key, operation_type) DO NOTHING;
  END IF;

  INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
  VALUES (
    v_sender_id, 'user', 'ksp_transfer', 'transaction', v_tx_id::TEXT,
    jsonb_build_object('amount', p_amount, 'receiver_id', v_receiver_id),
    'info'
  );

  RETURN json_build_object(
    'success', TRUE,
    'transaction_id', v_tx_id,
    'receiver_name', v_receiver_name,
    'message', 'KSP transfer completed'
  );
END;
$$;

-- ── 11. create_transfer idempotent response includes receiver_name ──
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
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Invalid amount');
  END IF;

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
  WHERE UPPER(referral_code) = UPPER(REPLACE(p_receiver_referral_code, '-', ''))
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

-- ── 12. Race-safe withdrawal completion ──
CREATE OR REPLACE FUNCTION public.agent_confirm_withdrawal(p_transaction_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_user_id UUID := auth.uid();
  v_agent_id UUID;
  v_tx RECORD;
  v_updated INT;
BEGIN
  SELECT id INTO v_agent_id FROM agents WHERE user_id = v_agent_user_id LIMIT 1;
  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'message', 'Not an agent');
  END IF;

  SELECT * INTO v_tx FROM transactions
  WHERE id = p_transaction_id
    AND reference_id = v_agent_id::TEXT
    AND type = 'withdrawal'
    AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'message', 'Transaction not found or already processed');
  END IF;

  UPDATE transactions SET status = 'processing', updated_at = NOW()
  WHERE id = p_transaction_id AND status = 'pending';

  PERFORM id FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;

  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
    updated_at = NOW()
  WHERE id = v_tx.wallet_id;

  UPDATE transactions SET
    status = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW()
  WHERE id = p_transaction_id AND status = 'processing';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('success', FALSE, 'message', 'Concurrent processing detected');
  END IF;

  UPDATE agents SET total_transactions = total_transactions + 1 WHERE id = v_agent_id;

  PERFORM fn_log_financial_audit(
    v_agent_user_id, 'agent', 'withdrawal_approved', p_transaction_id,
    'pending', 'completed', v_tx.amount, NULL
  );

  RETURN json_build_object('success', TRUE);
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
  v_updated INT;
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_txn FROM transactions WHERE id = p_txn_id FOR UPDATE;
  IF NOT FOUND OR v_txn.type != 'withdrawal' OR v_txn.status != 'pending' THEN
    RETURN json_build_object('success', FALSE, 'error', 'Transaction not available for approval');
  END IF;

  UPDATE transactions SET status = 'processing', updated_at = NOW()
  WHERE id = p_txn_id AND status = 'pending';

  PERFORM id FROM wallets WHERE id = v_txn.wallet_id FOR UPDATE;

  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_txn.amount, 0),
    updated_at = NOW()
  WHERE id = v_txn.wallet_id;

  UPDATE transactions SET
    status = 'completed',
    processed_by = p_admin_id,
    processed_at = NOW()
  WHERE id = p_txn_id AND status = 'processing';

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RETURN json_build_object('success', FALSE, 'error', 'Concurrent processing detected');
  END IF;

  PERFORM fn_log_financial_audit(
    p_admin_id, 'admin', 'withdrawal_approved', p_txn_id,
    'pending', 'completed', v_txn.amount, NULL
  );

  RETURN json_build_object('success', TRUE, 'message', 'تمت الموافقة على السحب');
END;
$$;

-- ── 13. Transaction details RPC (secure, owner/agent/admin only) ──
CREATE OR REPLACE FUNCTION public.fn_get_transaction_details(p_transaction_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_tx RECORD;
  v_agent RECORD;
  v_counterpart RECORD;
  v_processor RECORD;
  v_can_view BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT * INTO v_tx FROM transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', FALSE, 'error', 'Not found');
  END IF;

  v_can_view := (v_tx.user_id = v_user_id)
    OR (v_tx.counterpart_user_id = v_user_id)
    OR is_admin();

  IF NOT v_can_view AND v_tx.reference_id IS NOT NULL THEN
    SELECT a.*, p.full_name AS agent_name, p.avatar_url AS agent_avatar,
           p.kyc_status AS agent_kyc, p.country AS agent_country
    INTO v_agent
    FROM agents a
    JOIN profiles p ON p.id = a.user_id
    WHERE a.id::TEXT = v_tx.reference_id AND a.user_id = v_user_id;

    IF FOUND THEN v_can_view := TRUE; END IF;
  END IF;

  IF NOT v_can_view THEN
    RETURN json_build_object('success', FALSE, 'error', 'Forbidden');
  END IF;

  IF v_tx.counterpart_user_id IS NOT NULL THEN
    SELECT id, full_name, avatar_url, referral_code, kyc_status, role, account_tier, country
    INTO v_counterpart FROM profiles WHERE id = v_tx.counterpart_user_id;
  END IF;

  IF v_tx.reference_id IS NOT NULL AND v_agent IS NULL THEN
    SELECT a.id, a.user_id, p.full_name AS agent_name, p.avatar_url AS agent_avatar,
           p.kyc_status AS agent_kyc, p.country AS agent_country, p.phone AS agent_phone
    INTO v_agent
    FROM agents a
    JOIN profiles p ON p.id = a.user_id
    WHERE a.id::TEXT = v_tx.reference_id;
  END IF;

  IF v_tx.processed_by IS NOT NULL THEN
    SELECT id, full_name INTO v_processor FROM profiles WHERE id = v_tx.processed_by;
  END IF;

  RETURN json_build_object(
    'success', TRUE,
    'transaction', json_build_object(
      'id', v_tx.id,
      'type', v_tx.type,
      'amount', v_tx.amount,
      'fee', COALESCE(v_tx.fee, 0),
      'net_amount', v_tx.amount - COALESCE(v_tx.fee, 0),
      'currency', v_tx.currency,
      'status', v_tx.status,
      'description', v_tx.description,
      'reference_id', v_tx.reference_id,
      'proof_url', v_tx.proof_url,
      'rejection_reason', v_tx.rejection_reason,
      'idempotency_key', v_tx.idempotency_key,
      'running_balance', v_tx.running_balance,
      'created_at', v_tx.created_at,
      'processed_at', v_tx.processed_at,
      'counterpart', CASE WHEN v_counterpart.id IS NOT NULL THEN json_build_object(
        'id', v_counterpart.id,
        'full_name', v_counterpart.full_name,
        'avatar_url', v_counterpart.avatar_url,
        'referral_code', v_counterpart.referral_code,
        'kyc_status', v_counterpart.kyc_status,
        'role', v_counterpart.role,
        'account_tier', v_counterpart.account_tier,
        'country', v_counterpart.country,
        'is_verified', v_counterpart.kyc_status = 'verified'
      ) ELSE NULL END,
      'agent', CASE WHEN v_agent.id IS NOT NULL THEN json_build_object(
        'id', v_agent.id,
        'user_id', v_agent.user_id,
        'full_name', v_agent.agent_name,
        'avatar_url', v_agent.agent_avatar,
        'kyc_status', v_agent.agent_kyc,
        'country', v_agent.agent_country,
        'is_verified', v_agent.agent_kyc = 'verified'
      ) ELSE NULL END,
      'processor', CASE WHEN v_processor.id IS NOT NULL THEN json_build_object(
        'id', v_processor.id,
        'full_name', v_processor.full_name
      ) ELSE NULL END
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_transaction_details(UUID) TO authenticated;

-- ── 14. Enhanced get_my_team with enterprise member fields ──
CREATE OR REPLACE FUNCTION public.get_my_team()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_tree JSON;
  v_referral_code TEXT;
  v_total INTEGER := 0;
  v_active INTEGER := 0;
  v_inactive INTEGER := 0;
  v_new_today INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT COALESCE(referral_code, '') INTO v_referral_code FROM profiles WHERE id = v_user_id;

  WITH RECURSIVE team_tree AS (
    SELECT p.id, p.full_name, p.avatar_url, p.created_at, p.status, p.referral_code,
           p.referred_by AS parent_id, p.kyc_status, p.country, p.country_code,
           p.role, p.account_tier, p.last_login_at,
           1 AS level, ARRAY[p.id] AS path
    FROM profiles p WHERE p.referred_by = v_user_id
    UNION ALL
    SELECT p.id, p.full_name, p.avatar_url, p.created_at, p.status, p.referral_code,
           p.referred_by, p.kyc_status, p.country, p.country_code,
           p.role, p.account_tier, p.last_login_at,
           tt.level + 1, tt.path || p.id
    FROM profiles p
    INNER JOIN team_tree tt ON p.referred_by = tt.id
    WHERE tt.level < 5 AND NOT (p.id = ANY(tt.path))
  )
  SELECT COALESCE(json_agg(
    json_build_object(
      'id', t.id,
      'full_name', t.full_name,
      'avatar_url', t.avatar_url,
      'created_at', t.created_at,
      'status', t.status,
      'referral_code', t.referral_code,
      'parent_id', t.parent_id,
      'level', t.level,
      'member_type', 'referral',
      'kyc_status', t.kyc_status,
      'country', COALESCE(NULLIF(t.country, ''), t.country_code, ''),
      'role', t.role,
      'account_tier', t.account_tier,
      'last_active', t.last_login_at,
      'is_agent', EXISTS (SELECT 1 FROM agents a WHERE a.user_id = t.id AND a.status = 'active'),
      'is_premium', t.account_tier IN ('vip', 'premium'),
      'is_verified', t.kyc_status = 'verified',
      'investment_amount', COALESCE((
        SELECT SUM(ui.amount) FROM user_investments ui
        WHERE ui.user_id = t.id AND ui.status IN ('active', 'completed')
      ), 0),
      'current_investment', COALESCE((
        SELECT SUM(ui.amount) FROM user_investments ui
        WHERE ui.user_id = t.id AND ui.status = 'active'
      ), 0),
      'referral_earnings', COALESCE((
        SELECT SUM(re.commission_amount) FROM referral_earnings re WHERE re.investor_id = t.id
      ), 0),
      'direct_referrals', (SELECT COUNT(*) FROM profiles WHERE referred_by = t.id)
    ) ORDER BY t.level, t.created_at DESC
  ), '[]'::JSON) INTO v_tree FROM team_tree t;

  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status = 'active'),
    COUNT(*) FILTER (WHERE status <> 'active'),
    COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE)
  INTO v_total, v_active, v_inactive, v_new_today
  FROM profiles WHERE referred_by = v_user_id;

  RETURN json_build_object(
    'success', TRUE,
    'my_referral_code', v_referral_code,
    'total_members', v_total,
    'active_members', v_active,
    'inactive_members', v_inactive,
    'new_today', v_new_today,
    'tree', v_tree
  );
END;
$$;

-- ── 15. Team statistics RPC ──
CREATE OR REPLACE FUNCTION public.get_team_statistics()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  RETURN (
    WITH RECURSIVE team AS (
      SELECT id, status, created_at, kyc_status, role, account_tier
      FROM profiles WHERE referred_by = v_user_id
      UNION ALL
      SELECT p.id, p.status, p.created_at, p.kyc_status, p.role, p.account_tier
      FROM profiles p JOIN team t ON p.referred_by = t.id
    ),
    earnings AS (
      SELECT
        COALESCE(SUM(commission_amount), 0) AS lifetime,
        COALESCE(SUM(commission_amount) FILTER (WHERE created_at >= CURRENT_DATE), 0) AS today,
        COALESCE(SUM(commission_amount) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)), 0) AS monthly
      FROM referral_earnings WHERE referrer_id = v_user_id
    ),
    investments AS (
      SELECT COALESCE(SUM(ui.amount), 0) AS total_team_investment,
             COALESCE(AVG(ui.amount), 0) AS avg_investment,
             MAX(ui.amount) AS highest_investment
      FROM user_investments ui
      JOIN team t ON t.id = ui.user_id
      WHERE ui.status IN ('active', 'completed')
    ),
    newest AS (
      SELECT full_name, created_at FROM profiles
      WHERE referred_by = v_user_id ORDER BY created_at DESC LIMIT 1
    ),
    top_investor AS (
      SELECT p.full_name, SUM(ui.amount) AS total
      FROM user_investments ui
      JOIN profiles p ON p.id = ui.user_id
      JOIN team t ON t.id = ui.user_id
      WHERE ui.status IN ('active', 'completed')
      GROUP BY p.full_name ORDER BY total DESC LIMIT 1
    )
    SELECT json_build_object(
      'success', TRUE,
      'total_members', (SELECT COUNT(*) FROM team),
      'active_members', (SELECT COUNT(*) FROM team WHERE status = 'active'),
      'inactive_members', (SELECT COUNT(*) FROM team WHERE status <> 'active'),
      'registered_today', (SELECT COUNT(*) FROM team WHERE created_at >= CURRENT_DATE),
      'verified_users', (SELECT COUNT(*) FROM team WHERE kyc_status = 'verified'),
      'investors', (SELECT COUNT(DISTINCT ui.user_id) FROM user_investments ui JOIN team t ON t.id = ui.user_id),
      'non_investors', (SELECT COUNT(*) FROM team) - (SELECT COUNT(DISTINCT ui.user_id) FROM user_investments ui JOIN team t ON t.id = ui.user_id),
      'agents', (SELECT COUNT(*) FROM team t JOIN agents a ON a.user_id = t.id AND a.status = 'active'),
      'premium_members', (SELECT COUNT(*) FROM team WHERE account_tier IN ('vip', 'premium')),
      'total_team_investment', (SELECT total_team_investment FROM investments),
      'total_referral_earnings', (SELECT lifetime FROM earnings),
      'today_referral_earnings', (SELECT today FROM earnings),
      'monthly_referral_earnings', (SELECT monthly FROM earnings),
      'lifetime_referral_earnings', (SELECT lifetime FROM earnings),
      'average_investment', (SELECT avg_investment FROM investments),
      'highest_investor', (SELECT full_name FROM top_investor),
      'highest_investment', (SELECT total FROM top_investor),
      'newest_member', (SELECT full_name FROM newest),
      'newest_member_date', (SELECT created_at FROM newest)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_team_statistics() TO authenticated;

-- ── 16. Referral timeline RPC ──
CREATE OR REPLACE FUNCTION public.get_referral_timeline(p_limit INT DEFAULT 50)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_items JSON;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(x)), '[]'::JSON) INTO v_items
  FROM (
    SELECT ra.id, ra.event_type, ra.title, ra.body, ra.metadata, ra.created_at,
           p.full_name AS member_name, p.avatar_url AS member_avatar
    FROM referral_activity ra
    LEFT JOIN profiles p ON p.id = ra.member_id
    WHERE ra.referrer_id = v_user_id
    ORDER BY ra.created_at DESC
    LIMIT LEAST(p_limit, 100)
  ) x;

  RETURN json_build_object('success', TRUE, 'items', v_items);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_referral_timeline(INT) TO authenticated;

-- ── 17. Referral analytics RPC ──
CREATE OR REPLACE FUNCTION public.get_referral_analytics(p_days INT DEFAULT 30)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_since TIMESTAMPTZ := NOW() - (p_days || ' days')::INTERVAL;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  RETURN (
    WITH direct_refs AS (
      SELECT id, created_at, status, country, country_code
      FROM profiles WHERE referred_by = v_user_id AND created_at >= v_since
    ),
    daily_regs AS (
      SELECT DATE(created_at) AS d, COUNT(*) AS c
      FROM direct_refs GROUP BY 1 ORDER BY 1
    ),
    earnings AS (
      SELECT DATE(created_at) AS d, SUM(commission_amount) AS c
      FROM referral_earnings
      WHERE referrer_id = v_user_id AND created_at >= v_since
      GROUP BY 1 ORDER BY 1
    ),
    invested_refs AS (
      SELECT COUNT(DISTINCT p.id) AS invested,
             COUNT(DISTINCT p.id) FILTER (WHERE p.id IN (SELECT id FROM direct_refs)) AS total
      FROM profiles p
      LEFT JOIN user_investments ui ON ui.user_id = p.id AND ui.status IN ('active','completed')
      WHERE p.referred_by = v_user_id
    ),
    top_inviters AS (
      SELECT p.full_name, COUNT(child.id) AS referrals
      FROM profiles p
      JOIN profiles child ON child.referred_by = p.id
      WHERE p.referred_by = v_user_id
      GROUP BY p.full_name ORDER BY referrals DESC LIMIT 5
    ),
    countries AS (
      SELECT COALESCE(NULLIF(country,''), country_code, 'Unknown') AS c, COUNT(*) AS n
      FROM direct_refs GROUP BY 1 ORDER BY n DESC LIMIT 10
    )
    SELECT json_build_object(
      'success', TRUE,
      'daily_registrations', (SELECT COALESCE(json_agg(json_build_object('date', d, 'count', c)), '[]'::JSON) FROM daily_regs),
      'daily_earnings', (SELECT COALESCE(json_agg(json_build_object('date', d, 'amount', c)), '[]'::JSON) FROM earnings),
      'referral_conversion', CASE WHEN (SELECT total FROM invested_refs) > 0
        THEN ROUND((SELECT invested::NUMERIC FROM invested_refs) / (SELECT total FROM invested_refs) * 100, 2)
        ELSE 0 END,
      'investment_conversion', CASE WHEN (SELECT COUNT(*) FROM direct_refs) > 0
        THEN ROUND((SELECT invested::NUMERIC FROM invested_refs) / (SELECT COUNT(*) FROM direct_refs) * 100, 2)
        ELSE 0 END,
      'active_vs_inactive', json_build_object(
        'active', (SELECT COUNT(*) FROM profiles WHERE referred_by = v_user_id AND status = 'active'),
        'inactive', (SELECT COUNT(*) FROM profiles WHERE referred_by = v_user_id AND status <> 'active')
      ),
      'countries', (SELECT COALESCE(json_agg(json_build_object('country', c, 'count', n)), '[]'::JSON) FROM countries),
      'top_inviters', (SELECT COALESCE(json_agg(json_build_object('name', full_name, 'referrals', referrals)), '[]'::JSON) FROM top_inviters),
      'total_referrals_period', (SELECT COUNT(*) FROM direct_refs),
      'total_earnings_period', (SELECT COALESCE(SUM(commission_amount), 0) FROM referral_earnings WHERE referrer_id = v_user_id AND created_at >= v_since)
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_referral_analytics(INT) TO authenticated;

-- ── 18. Referral activity triggers for KYC and investments ──
CREATE OR REPLACE FUNCTION public.fn_referral_activity_on_kyc()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NEW.kyc_status = 'verified' AND OLD.kyc_status IS DISTINCT FROM 'verified'
     AND NEW.referred_by IS NOT NULL THEN
    PERFORM fn_log_referral_activity(
      NEW.referred_by, NEW.id, 'kyc_completed',
      COALESCE(NEW.full_name, 'عضو') || ' أكمل التحقق من الهوية',
      'تم توثيق الحساب بنجاح',
      jsonb_build_object('kyc_status', NEW.kyc_status)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_kyc_activity ON public.profiles;
CREATE TRIGGER trg_referral_kyc_activity
  AFTER UPDATE OF kyc_status ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.fn_referral_activity_on_kyc();

CREATE OR REPLACE FUNCTION public.fn_referral_activity_on_investment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_referrer_id UUID;
  v_name TEXT;
BEGIN
  SELECT referred_by, full_name INTO v_referrer_id, v_name
  FROM profiles WHERE id = NEW.user_id;

  IF v_referrer_id IS NOT NULL AND NEW.status = 'active' THEN
    PERFORM fn_log_referral_activity(
      v_referrer_id, NEW.user_id, 'investment_created',
      COALESCE(v_name, 'عضو') || ' استثمر $' || NEW.amount::TEXT,
      'استثمار جديد في الشبكة',
      jsonb_build_object('investment_id', NEW.id, 'amount', NEW.amount)
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_investment_activity ON public.user_investments;
CREATE TRIGGER trg_referral_investment_activity
  AFTER INSERT ON public.user_investments
  FOR EACH ROW EXECUTE FUNCTION public.fn_referral_activity_on_investment();

-- ── 19. fn_check_financial_permission: return JSON-friendly errors in RPCs ──
-- (Existing RAISE EXCEPTION is caught by RPC wrappers)

GRANT EXECUTE ON FUNCTION public.get_my_team() TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_registration_rewards(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_log_referral_activity(UUID, UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
