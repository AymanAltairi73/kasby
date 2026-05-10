-- ============================================================
-- KASBY - Complete Supabase Database Setup
-- Run this SQL in: Supabase Dashboard > SQL Editor
-- ============================================================

-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. PROFILES TABLE (linked to auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL,
  phone TEXT UNIQUE,
  avatar_url TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'blocked', 'suspended')),
  account_tier TEXT NOT NULL DEFAULT 'free' CHECK (account_tier IN ('free', 'verified', 'vip')),
  kyc_status TEXT NOT NULL DEFAULT 'unverified' CHECK (kyc_status IN ('unverified', 'pending', 'verified', 'rejected')),
  referral_code TEXT UNIQUE,
  referred_by UUID REFERENCES profiles(id),
  country_code TEXT,
  province TEXT DEFAULT '',
  city TEXT DEFAULT '',
  address TEXT DEFAULT '',
  whatsapp TEXT DEFAULT '',
  telegram TEXT DEFAULT '',
  last_login_at TIMESTAMPTZ,
  last_login_ip TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-generate referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
  code TEXT;
  exists_count INT;
BEGIN
  LOOP
    code := 'K-' || LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0') || '-' ||
            LPAD(FLOOR(RANDOM() * 100)::TEXT, 2, '0') || '-' ||
            LPAD(FLOOR(RANDOM() * 100)::TEXT, 2, '0');
    SELECT COUNT(*) INTO exists_count FROM profiles WHERE referral_code = code;
    EXIT WHEN exists_count = 0;
  END LOOP;
  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, phone, country_code, referral_code)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', NULL),
    COALESCE(NEW.raw_user_meta_data->>'country_code', NULL),
    generate_referral_code()
  );

  -- Create wallet for new user
  INSERT INTO wallets (id, user_id, currency)
  VALUES (uuid_generate_v4(), NEW.id, 'USD');

  -- Create user_points record
  INSERT INTO user_points (id, user_id)
  VALUES (uuid_generate_v4(), NEW.id);

  -- Handle referral
  IF NEW.raw_user_meta_data->>'referred_by_code' IS NOT NULL THEN
    UPDATE profiles SET referred_by = (
      SELECT id FROM profiles WHERE referral_code = NEW.raw_user_meta_data->>'referred_by_code'
    ) WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 2. WALLETS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  available_balance NUMERIC(15,2) DEFAULT 0.00,
  profit_balance NUMERIC(15,2) DEFAULT 0.00,
  invested_balance NUMERIC(15,2) DEFAULT 0.00,
  pending_balance NUMERIC(15,2) DEFAULT 0.00,
  currency TEXT NOT NULL DEFAULT 'USD',
  is_frozen BOOLEAN DEFAULT FALSE,
  frozen_reason TEXT,
  frozen_at TIMESTAMPTZ,
  frozen_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, currency)
);

-- ============================================================
-- 3. TRANSACTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  idempotency_key TEXT UNIQUE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'deposit', 'withdrawal', 'transfer_in', 'transfer_out',
    'investment', 'investment_return', 'loan_disbursement', 'loan_repayment',
    'reward', 'adjustment', 'profit', 'fee'
  )),
  amount NUMERIC(15,2) NOT NULL,
  fee NUMERIC(15,2) DEFAULT 0.00,
  net_amount NUMERIC(15,2) GENERATED ALWAYS AS (amount - fee) STORED,
  currency TEXT NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending', 'processing', 'completed', 'approved', 'rejected', 'cancelled', 'failed'
  )),
  running_balance NUMERIC(15,2),
  counterpart_user_id UUID REFERENCES profiles(id),
  reference_id TEXT,
  reason TEXT,
  description TEXT,
  proof_url TEXT,
  processed_by UUID REFERENCES profiles(id),
  processed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transactions_user_id ON transactions(user_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at DESC);

-- ============================================================
-- 4. NOTIFICATIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  target TEXT DEFAULT 'specific' CHECK (target IN ('all', 'specific')),
  target_user_id UUID REFERENCES profiles(id),
  status TEXT DEFAULT 'sent' CHECK (status IN ('sent', 'scheduled', 'failed', 'read')),
  sent_by UUID REFERENCES profiles(id),
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);

-- ============================================================
-- 5. CURRENCIES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS currencies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  code TEXT UNIQUE NOT NULL,
  symbol TEXT DEFAULT '',
  rate NUMERIC(15,6) NOT NULL DEFAULT 1.0,
  decimal_places INT DEFAULT 2,
  is_base BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  flag TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default currencies
INSERT INTO currencies (id, name, code, symbol, rate, is_base, is_active, flag) VALUES
  (uuid_generate_v4(), 'الدولار الأمريكي', 'USD', '$', 1.0, TRUE, TRUE, '🇺🇸'),
  (uuid_generate_v4(), 'الدينار العراقي', 'IQD', 'د.ع', 1320.0, FALSE, TRUE, '🇮🇶'),
  (uuid_generate_v4(), 'الدينار الكويتي', 'KWD', 'د.ك', 0.3071, FALSE, TRUE, '🇰🇼'),
  (uuid_generate_v4(), 'الريال السعودي', 'SAR', 'ر.س', 3.75, FALSE, TRUE, '🇸🇦'),
  (uuid_generate_v4(), 'الدرهم الإماراتي', 'AED', 'د.إ', 3.6725, FALSE, TRUE, '🇦🇪'),
  (uuid_generate_v4(), 'الدينار الأردني', 'JOD', 'د.أ', 0.7090, FALSE, TRUE, '🇯🇴'),
  (uuid_generate_v4(), 'الجنيه المصري', 'EGP', 'ج.م', 47.1, FALSE, TRUE, '🇪🇬'),
  (uuid_generate_v4(), 'الليرة التركية', 'TRY', '₺', 15.59, FALSE, TRUE, '🇹🇷'),
  (uuid_generate_v4(), 'اليورو', 'EUR', '€', 0.8461, FALSE, TRUE, '🇪🇺'),
  (uuid_generate_v4(), 'الفرنك السويسري', 'CHF', 'Fr', 0.7754, FALSE, TRUE, '🇨🇭'),
  (uuid_generate_v4(), 'الين الياباني', 'JPY', '¥', 155.9, FALSE, TRUE, '🇯🇵')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 6. AGENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS agents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES profiles(id),
  name TEXT NOT NULL,
  country TEXT DEFAULT '',
  province TEXT DEFAULT '',
  city TEXT DEFAULT '',
  address TEXT DEFAULT '',
  phone TEXT NOT NULL,
  whatsapp TEXT DEFAULT '',
  telegram TEXT DEFAULT '',
  email TEXT DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  is_available_now BOOLEAN DEFAULT FALSE,
  supported_methods JSONB DEFAULT '[]'::JSONB,
  success_rate NUMERIC(5,2) DEFAULT 0.00,
  total_transactions INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. INVESTMENT PLANS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS investment_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name_ar TEXT NOT NULL,
  name_en TEXT,
  description_ar TEXT DEFAULT '',
  description_en TEXT,
  image_url TEXT,
  profit_percentage NUMERIC(6,2) NOT NULL,
  duration_days INT,
  min_amount NUMERIC(15,2) NOT NULL,
  max_amount NUMERIC(15,2),
  available_amounts JSONB,
  risk_level TEXT DEFAULT 'medium' CHECK (risk_level IN ('low', 'medium', 'high')),
  is_active BOOLEAN DEFAULT TRUE,
  version INT DEFAULT 1,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. USER INVESTMENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS user_investments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES investment_plans(id),
  transaction_id UUID REFERENCES transactions(id),
  amount NUMERIC(15,2) NOT NULL,
  profit_percentage NUMERIC(6,2) NOT NULL,
  expected_profit NUMERIC(15,2) DEFAULT 0.00,
  actual_profit NUMERIC(15,2),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled', 'matured')),
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  matured_at TIMESTAMPTZ,
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_user_investments_user_id ON user_investments(user_id);

-- ============================================================
-- 9. LOANS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS loans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  amount NUMERIC(15,2) NOT NULL,
  interest_rate NUMERIC(6,2) DEFAULT 0.00,
  total_due NUMERIC(15,2) GENERATED ALWAYS AS (amount + (amount * interest_rate / 100)) STORED,
  paid_amount NUMERIC(15,2) DEFAULT 0.00,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'current', 'paid', 'delayed', 'defaulted', 'overdue')),
  loan_date TIMESTAMPTZ,
  repayment_date TIMESTAMPTZ NOT NULL,
  approved_by UUID REFERENCES profiles(id),
  approved_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_loans_user_id ON loans(user_id);

-- ============================================================
-- 10. DAILY CHECK-INS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_check_ins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  points_awarded INT DEFAULT 10,
  streak INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_daily_check_ins_user_id ON daily_check_ins(user_id);

-- ============================================================
-- 11. USER POINTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS user_points (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  current_balance INT DEFAULT 0,
  total_earned INT DEFAULT 0,
  total_spent INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 12. POINT HISTORY TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS point_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  points INT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('earn', 'spend', 'transfer_in', 'transfer_out')),
  description TEXT,
  reference_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_point_history_user_id ON point_history(user_id);

-- ============================================================
-- 13. SUBSCRIPTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  tier TEXT NOT NULL DEFAULT 'vip' CHECK (tier IN ('vip', 'premium')),
  is_yearly BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
  start_date TIMESTAMPTZ DEFAULT NOW(),
  end_date TIMESTAMPTZ NOT NULL,
  price NUMERIC(15,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_subscriptions_user_id ON subscriptions(user_id);

-- ============================================================
-- 14. KYC DOCUMENTS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS kyc_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  document_type TEXT NOT NULL CHECK (document_type IN (
    'id_card_front', 'id_card_back', 'passport', 'selfie', 'proof_of_address', 'other'
  )),
  document_url TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'rejected', 'unverified')),
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  rejection_reason TEXT,
  uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_kyc_documents_user_id ON kyc_documents(user_id);

-- ============================================================
-- 15. FEES TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS fees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  label TEXT NOT NULL,
  value TEXT NOT NULL,
  percentage NUMERIC(6,2),
  fixed_amount NUMERIC(15,2),
  category TEXT NOT NULL CHECK (category IN ('deposit', 'withdraw', 'investment', 'transfer', 'loan')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 16. SYSTEM SETTINGS TABLE (singleton)
-- ============================================================
CREATE TABLE IF NOT EXISTS system_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pause_deposits BOOLEAN DEFAULT FALSE,
  pause_withdrawals BOOLEAN DEFAULT FALSE,
  pause_profits BOOLEAN DEFAULT FALSE,
  pause_investments BOOLEAN DEFAULT FALSE,
  pause_loans BOOLEAN DEFAULT FALSE,
  system_freeze BOOLEAN DEFAULT FALSE,
  is_maintenance_mode BOOLEAN DEFAULT FALSE,
  maintenance_message TEXT DEFAULT '',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  updated_by UUID REFERENCES profiles(id)
);

-- Seed a default settings row
INSERT INTO system_settings (id) VALUES (uuid_generate_v4())
ON CONFLICT DO NOTHING;

-- ============================================================
-- 17. VIEW: v_user_dashboard
-- ============================================================
CREATE OR REPLACE VIEW v_user_dashboard AS
SELECT 
    p.id AS user_id, 
    p.full_name, 
    p.account_tier, 
    p.kyc_status,
    COALESCE(w.available_balance, 0) AS available_balance, 
    COALESCE(w.profit_balance, 0) AS profit_balance, 
    COALESCE(w.invested_balance, 0) AS invested_balance, 
    COALESCE(w.pending_balance, 0) AS pending_balance,
    COALESCE(w.is_frozen, FALSE) AS is_frozen, 
    COALESCE(w.currency, 'USD') AS currency, 
    COALESCE(up.current_balance, 0) AS point_balance,
    (SELECT COUNT(*) FROM user_investments ui WHERE ui.user_id = p.id AND ui.status = 'active')::INT AS active_investments,
    (SELECT COUNT(*) FROM loans l WHERE l.user_id = p.id AND l.status = 'current')::INT AS active_loans,
    (SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE user_id = p.id AND type = 'profit' AND created_at >= NOW() - INTERVAL '24 hours') AS daily_profit,
    CASE WHEN COALESCE(w.invested_balance, 0) > 0 
         THEN ROUND(((SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE user_id = p.id AND type = 'profit' AND created_at >= NOW() - INTERVAL '24 hours') / w.invested_balance * 100), 2)
         ELSE 0 
    END AS profit_percentage
FROM profiles p
LEFT JOIN wallets w ON w.user_id = p.id AND w.currency = 'USD'
LEFT JOIN user_points up ON up.user_id = p.id;

-- ============================================================
-- 18. RPC FUNCTIONS
-- ============================================================

-- 18.1 daily_check_in
CREATE OR REPLACE FUNCTION daily_check_in()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_last_check TIMESTAMPTZ;
  v_streak INT := 1;
  v_points INT := 10;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- Get last check-in
  SELECT created_at, streak INTO v_last_check, v_streak
  FROM daily_check_ins
  WHERE user_id = v_user_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- Check if already checked in today
  IF v_last_check IS NOT NULL AND v_last_check::DATE = CURRENT_DATE THEN
    RETURN jsonb_build_object('success', false, 'error', 'لقد سجلت الدخول اليوم بالفعل');
  END IF;

  -- Calculate streak
  IF v_last_check IS NOT NULL AND v_last_check::DATE = (CURRENT_DATE - INTERVAL '1 day')::DATE THEN
    v_streak := COALESCE(v_streak, 0) + 1;
  ELSE
    v_streak := 1;
  END IF;

  -- Bonus for streaks
  v_points := 10 + (v_streak * 2);

  -- Insert check-in
  INSERT INTO daily_check_ins (user_id, points_awarded, streak)
  VALUES (v_user_id, v_points, v_streak);

  -- Update points
  UPDATE user_points SET
    current_balance = current_balance + v_points,
    total_earned = total_earned + v_points,
    updated_at = NOW()
  WHERE user_id = v_user_id;

  -- Record in point history
  INSERT INTO point_history (user_id, points, type, description)
  VALUES (v_user_id, v_points, 'earn', 'مكافأة تسجيل الدخول اليومي');

  RETURN jsonb_build_object(
    'success', true,
    'streak', v_streak,
    'points_awarded', v_points,
    'message', 'تم تسجيل الدخول! حصلت على ' || v_points || ' نقطة'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18.2 claim_spin_reward
CREATE OR REPLACE FUNCTION claim_spin_reward(p_reward_points INT)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  IF p_reward_points <= 0 THEN
    RETURN jsonb_build_object('success', true, 'message', 'لا توجد نقاط لاستلامها');
  END IF;

  -- Add points
  UPDATE user_points SET
    current_balance = current_balance + p_reward_points,
    total_earned = total_earned + p_reward_points,
    updated_at = NOW()
  WHERE user_id = v_user_id;

  -- Record in history
  INSERT INTO point_history (user_id, points, type, description)
  VALUES (v_user_id, p_reward_points, 'earn', 'مكافأة عجلة الحظ');

  RETURN jsonb_build_object(
    'success', true,
    'points_awarded', p_reward_points,
    'message', 'تم استلام ' || p_reward_points || ' نقطة!'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18.3 create_withdrawal
CREATE OR REPLACE FUNCTION create_withdrawal(p_amount NUMERIC, p_agent_id UUID, p_currency TEXT DEFAULT 'USD')
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet wallets%ROWTYPE;
  v_tx_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- Get wallet
  SELECT * INTO v_wallet FROM wallets
  WHERE user_id = v_user_id AND currency = p_currency;

  IF v_wallet IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'المحفظة غير موجودة');
  END IF;

  IF v_wallet.is_frozen THEN
    RETURN jsonb_build_object('success', false, 'error', 'المحفظة مجمدة');
  END IF;

  IF v_wallet.available_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'رصيد غير كافٍ');
  END IF;

  IF p_amount < 10 THEN
    RETURN jsonb_build_object('success', false, 'error', 'الحد الأدنى للسحب هو $10');
  END IF;

  -- Create transaction
  INSERT INTO transactions (user_id, wallet_id, type, amount, currency, status, reference_id, description)
  VALUES (v_user_id, v_wallet.id, 'withdrawal', p_amount, p_currency, 'pending', p_agent_id::TEXT, 'طلب سحب')
  RETURNING id INTO v_tx_id;

  -- Deduct from available balance and move to pending
  UPDATE wallets SET
    available_balance = available_balance - p_amount,
    pending_balance = pending_balance + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet.id;

  -- Notify
  INSERT INTO notifications (user_id, title, message)
  VALUES (v_user_id, 'طلب سحب جديد', 'تم استلام طلب سحب بقيمة $' || p_amount || ' وهو قيد المراجعة.');

  RETURN jsonb_build_object(
    'success', true,
    'transaction_id', v_tx_id,
    'message', 'تم استلام طلب السحب بنجاح وسيتم مراجعته قريباً'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18.4 create_transfer
CREATE OR REPLACE FUNCTION create_transfer(p_amount NUMERIC, p_receiver_referral_code TEXT, p_transfer_type TEXT DEFAULT 'funds')
RETURNS JSONB AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_receiver profiles%ROWTYPE;
  v_sender_wallet wallets%ROWTYPE;
  v_receiver_wallet wallets%ROWTYPE;
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- Get receiver
  SELECT * INTO v_receiver FROM profiles WHERE referral_code = p_receiver_referral_code;
  IF v_receiver IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'رمز المستلم غير صحيح');
  END IF;

  IF v_receiver.id = v_sender_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'لا يمكنك التحويل لنفسك');
  END IF;

  IF p_transfer_type = 'points' THEN
    -- Points transfer
    DECLARE v_sender_points INT;
    BEGIN
      SELECT current_balance INTO v_sender_points FROM user_points WHERE user_id = v_sender_id;
      IF v_sender_points < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'نقاط غير كافية');
      END IF;

      UPDATE user_points SET current_balance = current_balance - p_amount::INT, total_spent = total_spent + p_amount::INT WHERE user_id = v_sender_id;
      UPDATE user_points SET current_balance = current_balance + p_amount::INT, total_earned = total_earned + p_amount::INT WHERE user_id = v_receiver.id;

      INSERT INTO point_history (user_id, points, type, description) VALUES (v_sender_id, p_amount::INT, 'transfer_out', 'تحويل نقاط إلى ' || v_receiver.full_name);
      INSERT INTO point_history (user_id, points, type, description) VALUES (v_receiver.id, p_amount::INT, 'transfer_in', 'نقاط مستلمة');
    END;
  ELSE
    -- Funds transfer (pending admin approval)
    SELECT * INTO v_sender_wallet FROM wallets WHERE user_id = v_sender_id AND currency = 'USD';
    IF v_sender_wallet.available_balance < p_amount THEN
      RETURN jsonb_build_object('success', false, 'error', 'رصيد غير كافٍ');
    END IF;

    -- Deduct and pend
    UPDATE wallets SET available_balance = available_balance - p_amount, pending_balance = pending_balance + p_amount WHERE id = v_sender_wallet.id;

    INSERT INTO transactions (user_id, wallet_id, type, amount, currency, status, counterpart_user_id, description)
    VALUES (v_sender_id, v_sender_wallet.id, 'transfer_out', p_amount, 'USD', 'pending', v_receiver.id, 'تحويل رصيد');
  END IF;

  -- Notify both
  INSERT INTO notifications (user_id, title, message) VALUES
    (v_sender_id, 'تم إرسال طلب تحويل', 'تم إرسال طلب تحويل بقيمة ' || p_amount || ' وهو قيد المراجعة'),
    (v_receiver.id, 'تحويل وارد', 'لديك تحويل وارد بقيمة ' || p_amount);

  RETURN jsonb_build_object(
    'success', true,
    'receiver_name', v_receiver.full_name,
    'message', 'تم إرسال طلب التحويل بنجاح'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18.5 create_loan
CREATE OR REPLACE FUNCTION create_loan(p_amount NUMERIC, p_duration_months INT, p_receive_as_points BOOLEAN DEFAULT FALSE)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet wallets%ROWTYPE;
  v_interest_rate NUMERIC := 10.0; -- 10% per month
  v_total_interest NUMERIC;
  v_repayment_date TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_user_id AND currency = 'USD';

  IF v_wallet IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'المحفظة غير موجودة');
  END IF;

  IF v_wallet.invested_balance <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'يجب أن يكون لديك استثمارات نشطة');
  END IF;

  -- Validate the loan is within 10-40% of invested balance
  IF p_amount < v_wallet.invested_balance * 0.10 OR p_amount > v_wallet.invested_balance * 0.40 THEN
    RETURN jsonb_build_object('success', false, 'error', 'المبلغ خارج النطاق المسموح');
  END IF;

  v_total_interest := p_amount * (v_interest_rate / 100) * p_duration_months;
  v_repayment_date := NOW() + (p_duration_months || ' months')::INTERVAL;

  -- Create loan
  INSERT INTO loans (user_id, amount, interest_rate, status, loan_date, repayment_date)
  VALUES (v_user_id, p_amount, v_interest_rate * p_duration_months, 'pending', NOW(), v_repayment_date);

  -- Notify
  INSERT INTO notifications (user_id, title, message)
  VALUES (v_user_id, 'طلب قرض جديد', 'تم استلام طلب قرض بقيمة $' || p_amount || ' وسيتم مراجعته.');

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تقديم طلب القرض بنجاح. سيتم مراجعته من قبل الإدارة.'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18.6 create_investment
CREATE OR REPLACE FUNCTION create_investment(p_plan_id UUID, p_amount NUMERIC)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_plan investment_plans%ROWTYPE;
  v_wallet wallets%ROWTYPE;
  v_expected_profit NUMERIC;
  v_end_date TIMESTAMPTZ;
  v_tx_id UUID;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  SELECT * INTO v_plan FROM investment_plans WHERE id = p_plan_id AND is_active = TRUE;
  IF v_plan IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'خطة الاستثمار غير موجودة أو غير نشطة');
  END IF;

  IF p_amount < v_plan.min_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'المبلغ أقل من الحد الأدنى');
  END IF;

  IF v_plan.max_amount IS NOT NULL AND p_amount > v_plan.max_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'المبلغ أعلى من الحد الأقصى');
  END IF;

  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_user_id AND currency = 'USD';
  IF v_wallet.available_balance < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'رصيد غير كافٍ');
  END IF;

  v_expected_profit := p_amount * (v_plan.profit_percentage / 100);
  v_end_date := CASE
    WHEN v_plan.duration_days IS NOT NULL THEN NOW() + (v_plan.duration_days || ' days')::INTERVAL
    ELSE NULL
  END;

  -- Create transaction
  INSERT INTO transactions (user_id, wallet_id, type, amount, currency, status, description)
  VALUES (v_user_id, v_wallet.id, 'investment', p_amount, 'USD', 'completed', 'استثمار في ' || v_plan.name_ar)
  RETURNING id INTO v_tx_id;

  -- Update balances
  UPDATE wallets SET
    available_balance = available_balance - p_amount,
    invested_balance = invested_balance + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet.id;

  -- Create investment record
  INSERT INTO user_investments (user_id, plan_id, transaction_id, amount, profit_percentage, expected_profit, start_date, end_date)
  VALUES (v_user_id, p_plan_id, v_tx_id, p_amount, v_plan.profit_percentage, v_expected_profit, NOW(), v_end_date);

  -- Notify
  INSERT INTO notifications (user_id, title, message)
  VALUES (v_user_id, 'استثمار جديد', 'تم استثمار $' || p_amount || ' في ' || v_plan.name_ar || ' بنجاح!');

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم الاستثمار بنجاح!'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 18.7 buy_subscription
CREATE OR REPLACE FUNCTION buy_subscription(p_tier TEXT DEFAULT 'vip', p_is_yearly BOOLEAN DEFAULT FALSE)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet wallets%ROWTYPE;
  v_price NUMERIC;
  v_end_date TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- Pricing
  IF p_tier = 'vip' THEN
    v_price := CASE WHEN p_is_yearly THEN 99.99 ELSE 9.99 END;
  ELSE
    v_price := CASE WHEN p_is_yearly THEN 199.99 ELSE 19.99 END;
  END IF;

  v_end_date := CASE WHEN p_is_yearly THEN NOW() + INTERVAL '1 year' ELSE NOW() + INTERVAL '1 month' END;

  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_user_id AND currency = 'USD';
  IF v_wallet.available_balance < v_price THEN
    RETURN jsonb_build_object('success', false, 'error', 'رصيد غير كافٍ');
  END IF;

  -- Deduct
  UPDATE wallets SET available_balance = available_balance - v_price WHERE id = v_wallet.id;

  -- Expire old subscriptions
  UPDATE subscriptions SET status = 'expired' WHERE user_id = v_user_id AND status = 'active';

  -- Create new subscription
  INSERT INTO subscriptions (user_id, tier, is_yearly, end_date, price)
  VALUES (v_user_id, p_tier, p_is_yearly, v_end_date, v_price);

  -- Upgrade profile tier
  UPDATE profiles SET account_tier = p_tier WHERE id = v_user_id;

  -- Transaction record
  INSERT INTO transactions (user_id, wallet_id, type, amount, currency, status, description)
  VALUES (v_user_id, v_wallet.id, 'fee', v_price, 'USD', 'completed', 'اشتراك ' || p_tier);

  RETURN jsonb_build_object('success', true, 'message', 'تم تفعيل الاشتراك بنجاح!');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 19. ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE investment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- PROFILES
CREATE POLICY "Users can view own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Anyone can view profiles of active agents" ON profiles FOR SELECT 
  USING (EXISTS (SELECT 1 FROM agents WHERE agents.user_id = profiles.id AND agents.status = 'active'));
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- WALLETS
CREATE POLICY "Users can view own wallet" ON wallets FOR SELECT USING (auth.uid() = user_id);

-- TRANSACTIONS
CREATE POLICY "Users can view own transactions" ON transactions FOR SELECT USING (auth.uid() = user_id);

-- NOTIFICATIONS
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE USING (auth.uid() = user_id);

-- CURRENCIES (public read)
CREATE POLICY "Anyone can view currencies" ON currencies FOR SELECT USING (true);

-- AGENTS (public read for active)
CREATE POLICY "Anyone can view active agents" ON agents FOR SELECT USING (true);

-- INVESTMENT PLANS (public read for active)
CREATE POLICY "Anyone can view active plans" ON investment_plans FOR SELECT USING (is_active = true);

-- USER INVESTMENTS
CREATE POLICY "Users can view own investments" ON user_investments FOR SELECT USING (auth.uid() = user_id);

-- LOANS
CREATE POLICY "Users can view own loans" ON loans FOR SELECT USING (auth.uid() = user_id);

-- DAILY CHECK-INS
CREATE POLICY "Users can view own check-ins" ON daily_check_ins FOR SELECT USING (auth.uid() = user_id);

-- USER POINTS
CREATE POLICY "Users can view own points" ON user_points FOR SELECT USING (auth.uid() = user_id);

-- POINT HISTORY
CREATE POLICY "Users can view own point history" ON point_history FOR SELECT USING (auth.uid() = user_id);

-- SUBSCRIPTIONS
CREATE POLICY "Users can view own subscriptions" ON subscriptions FOR SELECT USING (auth.uid() = user_id);

-- KYC DOCUMENTS
CREATE POLICY "Users can view own KYC docs" ON kyc_documents FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own KYC docs" ON kyc_documents FOR INSERT WITH CHECK (auth.uid() = user_id);

-- FEES (public read)
CREATE POLICY "Anyone can view fees" ON fees FOR SELECT USING (is_active = true);

-- SYSTEM SETTINGS (public read)
CREATE POLICY "Anyone can view system settings" ON system_settings FOR SELECT USING (true);

-- ============================================================
-- 20. STORAGE BUCKET
-- ============================================================
-- Run this in Supabase Dashboard > Storage:
-- Create a bucket named 'documents' with public access enabled
-- ============================================================
-- 29. STORAGE BUCKETS
-- ============================================================

-- Documents bucket (for KYC)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

-- Avatars bucket (for Profile Pictures)
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 30. STORAGE POLICIES
-- ============================================================

-- Allow public access to view any avatar
CREATE POLICY "Public Access" ON storage.objects
FOR SELECT USING (bucket_id = 'avatars');

-- Allow users to upload their own avatar
-- The filename should match their user_id
CREATE POLICY "Users can upload their own avatar" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'avatars' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to update their own avatar
CREATE POLICY "Users can update their own avatar" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'avatars' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow users to delete their own avatar
CREATE POLICY "Users can delete their own avatar" ON storage.objects
FOR DELETE USING (
  bucket_id = 'avatars' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Policy for documents (KYC) - Only owner can upload/view
CREATE POLICY "Users can manage their own documents" ON storage.objects
FOR ALL USING (
  bucket_id = 'documents' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Storage policies
CREATE POLICY "Users can upload KYC docs" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'documents' AND auth.uid() IS NOT NULL);

  USING (bucket_id = 'documents');

-- ============================================================
-- DONE! Your Kasby database is ready.
-- ============================================================
