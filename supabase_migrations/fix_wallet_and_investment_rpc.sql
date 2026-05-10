-- ============================================================================
-- KASBY MASTER FIX: Robust Financial System & Auto-Provisioning (FINAL)
-- ============================================================================

-- 0. HELPERS: AUTO-PROVISIONING
CREATE OR REPLACE FUNCTION public.ensure_user_wallet(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    SELECT id INTO v_wallet_id FROM public.wallets WHERE user_id = p_user_id AND currency = 'USD' LIMIT 1;
    IF v_wallet_id IS NULL THEN
        INSERT INTO public.wallets (user_id, currency, available_balance, profit_balance, invested_balance, pending_balance)
        VALUES (p_user_id, 'USD', 0, 0, 0, 0)
        RETURNING id INTO v_wallet_id;
    END IF;
    RETURN v_wallet_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.ensure_user_points(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
    INSERT INTO public.user_points (user_id, current_balance, total_earned, total_spent)
    VALUES (p_user_id, 0, 0, 0)
    ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 1. CREATE INVESTMENT
DROP FUNCTION IF EXISTS public.create_investment(UUID, NUMERIC, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_investment(UUID, DECIMAL, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_investment(UUID, NUMERIC, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.create_investment(UUID, DECIMAL, UUID) CASCADE;

CREATE OR REPLACE FUNCTION public.create_investment(
  p_plan_id UUID,
  p_amount NUMERIC,
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_plan RECORD;
  v_wallet_id UUID;
  v_wallet RECORD;
  v_tx_id UUID;
  v_investment_id UUID;
  v_profit_rate NUMERIC;
BEGIN
  IF v_user_id IS NULL THEN RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); END IF;

  v_wallet_id := public.ensure_user_wallet(v_user_id);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT reference_id::UUID INTO v_investment_id FROM transactions WHERE idempotency_key = p_idempotency_key AND type = 'investment';
    IF FOUND THEN RETURN json_build_object('success', true, 'investment_id', v_investment_id, 'message', 'تم تنفيذ هذه العملية مسبقاً'); END IF;
  END IF;

  SELECT * INTO v_plan FROM investment_plans WHERE id = p_plan_id AND is_active = true;
  IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'خطة الاستثمار غير متاحة'); END IF;

  v_profit_rate := v_plan.profit_percentage;

  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;
  IF v_wallet.is_frozen THEN RETURN json_build_object('success', false, 'error', 'المحفظة مجمدة'); END IF;
  IF v_wallet.available_balance < p_amount THEN RETURN json_build_object('success', false, 'error', 'الرصيد غير كافٍ'); END IF;

  INSERT INTO transactions (user_id, wallet_id, type, amount, currency, status, running_balance, description, idempotency_key)
  VALUES (v_user_id, v_wallet.id, 'investment', p_amount, 'USD', 'pending', v_wallet.available_balance - p_amount, 'طلب استثمار في خطة ' || v_plan.name_ar, p_idempotency_key)
  RETURNING id INTO v_tx_id;

  INSERT INTO user_investments (user_id, plan_id, transaction_id, amount, profit_percentage, expected_profit, status, start_date, end_date, idempotency_key)
  VALUES (v_user_id, p_plan_id, v_tx_id, p_amount, v_profit_rate, (p_amount * v_profit_rate / 100), 'pending', NOW(), NOW() + INTERVAL '30 months', p_idempotency_key)
  RETURNING id INTO v_investment_id;
  
  UPDATE transactions SET reference_id = v_investment_id::TEXT WHERE id = v_tx_id;
  UPDATE wallets SET available_balance = available_balance - p_amount, pending_balance = pending_balance + p_amount, updated_at = NOW() WHERE id = v_wallet.id;

  RETURN json_build_object('success', true, 'investment_id', v_investment_id, 'message', 'تم تقديم طلب الاستثمار بنجاح');
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 2. BUY SUBSCRIPTION
DROP FUNCTION IF EXISTS public.buy_subscription(account_tier, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS public.buy_subscription(TEXT, BOOLEAN) CASCADE;

CREATE OR REPLACE FUNCTION public.buy_subscription(
    p_tier TEXT,
    p_is_yearly BOOLEAN
)
RETURNS JSON AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_amount NUMERIC(18, 4);
    v_wallet_id UUID;
    v_wallet RECORD;
    v_new_txn_id UUID;
    v_duration INTERVAL;
BEGIN
    IF v_user_id IS NULL THEN RETURN json_build_object('success', FALSE, 'error', 'Unauthorized'); END IF;
    v_wallet_id := public.ensure_user_wallet(v_user_id);

    IF p_is_yearly THEN v_amount := 89.00; v_duration := INTERVAL '1 year'; ELSE v_amount := 9.00; v_duration := INTERVAL '1 month'; END IF;

    SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;
    IF v_wallet.available_balance < v_amount THEN RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance'); END IF;

    UPDATE wallets SET available_balance = available_balance - v_amount, updated_at = NOW() WHERE id = v_wallet_id;

    INSERT INTO transactions (user_id, wallet_id, type, amount, status, description)
    VALUES (v_user_id, v_wallet_id, 'fee', v_amount, 'completed', 'Premium Subscription: ' || p_tier)
    RETURNING id INTO v_new_txn_id;

    UPDATE profiles SET account_tier = p_tier::account_tier, updated_at = NOW() WHERE id = v_user_id;

    INSERT INTO subscriptions (user_id, tier, is_yearly, amount, end_date, payment_transaction_id, status)
    VALUES (v_user_id, p_tier::account_tier, p_is_yearly, v_amount, NOW() + v_duration, v_new_txn_id, 'active');

    RETURN json_build_object('success', TRUE, 'message', 'Subscription activated successfully');
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 3. CREATE TRANSFER
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_transfer(DECIMAL, TEXT, TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.create_transfer(
  p_amount NUMERIC,
  p_receiver_referral_code TEXT,
  p_transfer_type TEXT DEFAULT 'funds'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_receiver RECORD;
  v_sender_wallet_id UUID;
  v_receiver_wallet_id UUID;
  v_sender_wallet RECORD;
  v_receiver_wallet RECORD;
  v_tx_out_id UUID;
BEGIN
  IF v_sender_id IS NULL THEN RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); END IF;
  v_sender_wallet_id := public.ensure_user_wallet(v_sender_id);

  SELECT id, full_name INTO v_receiver FROM profiles WHERE referral_code = p_receiver_referral_code;
  IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'كود الإحالة غير صالح'); END IF;
  IF v_receiver.id = v_sender_id THEN RETURN json_build_object('success', false, 'error', 'لا يمكنك التحويل لنفسك'); END IF;

  v_receiver_wallet_id := public.ensure_user_wallet(v_receiver.id);

  SELECT * INTO v_sender_wallet FROM wallets WHERE id = v_sender_wallet_id FOR UPDATE;
  IF v_sender_wallet.is_frozen THEN RETURN json_build_object('success', false, 'error', 'المحفظة غير متاحة'); END IF;
  IF v_sender_wallet.available_balance < p_amount THEN RETURN json_build_object('success', false, 'error', 'الرصيد غير كافٍ'); END IF;

  SELECT * INTO v_receiver_wallet FROM wallets WHERE id = v_receiver_wallet_id FOR UPDATE;

  UPDATE wallets SET available_balance = available_balance - p_amount WHERE id = v_sender_wallet_id;
  UPDATE wallets SET available_balance = available_balance + p_amount WHERE id = v_receiver_wallet_id;

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id)
  VALUES (v_sender_id, v_sender_wallet_id, 'transfer_out', p_amount, 'completed', 'تحويل إلى ' || v_receiver.full_name, v_receiver.id)
  RETURNING id INTO v_tx_out_id;

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id, reference_id)
  VALUES (v_receiver.id, v_receiver_wallet_id, 'transfer_in', p_amount, 'completed', 'تحويل مستلم من مستخدم', v_sender_id, v_tx_out_id::TEXT);

  RETURN json_build_object('success', true, 'message', 'تم التحويل بنجاح');
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 4. CREATE LOAN
DROP FUNCTION IF EXISTS public.create_loan(NUMERIC, INT, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS public.create_loan(DECIMAL, INT, BOOLEAN) CASCADE;

CREATE OR REPLACE FUNCTION public.create_loan(
  p_amount NUMERIC,
  p_duration_months INT,
  p_receive_as_points BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet_id UUID;
  v_wallet RECORD;
  v_interest_rate NUMERIC := 0.10;
  v_loan_id UUID;
BEGIN
  IF v_user_id IS NULL THEN RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); END IF;
  v_wallet_id := public.ensure_user_wallet(v_user_id);

  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;
  IF v_wallet.is_frozen THEN RETURN json_build_object('success', false, 'error', 'المحفظة غير متاحة'); END IF;

  IF v_wallet.invested_balance <= 0 THEN RETURN json_build_object('success', false, 'error', 'يجب أن يكون لديك استثمارات نشطة'); END IF;

  INSERT INTO loans (user_id, amount, interest_rate, paid_amount, status, repayment_date)
  VALUES (v_user_id, p_amount, v_interest_rate * 100, 0, 'pending', NOW() + (p_duration_months || ' months')::INTERVAL)
  RETURNING id INTO v_loan_id;

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, reference_id)
  VALUES (v_user_id, v_wallet_id, 'loan_disbursement', p_amount, 'pending', 'طلب قرض - ' || p_duration_months || ' شهر', v_loan_id::TEXT);

  RETURN json_build_object('success', true, 'loan_id', v_loan_id, 'message', 'تم تقديم طلب القرض بنجاح');
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 5. DAILY CHECK-IN
DROP FUNCTION IF EXISTS public.daily_check_in() CASCADE;
CREATE OR REPLACE FUNCTION public.daily_check_in()
RETURNS json AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_last_checkin TIMESTAMPTZ;
    v_current_streak INTEGER := 1;
    v_points_to_award INTEGER := 10;
BEGIN
    IF v_user_id IS NULL THEN RETURN json_build_object('success', FALSE, 'error', 'Unauthorized'); END IF;
    PERFORM public.ensure_user_points(v_user_id);

    SELECT created_at, streak INTO v_last_checkin, v_current_streak FROM daily_check_ins WHERE user_id = v_user_id ORDER BY created_at DESC LIMIT 1;
    
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE THEN
        RETURN json_build_object('success', FALSE, 'error', 'Already checked in today');
    END IF;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE - INTERVAL '1 day' THEN
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    IF v_current_streak % 7 = 0 THEN v_points_to_award := 50; ELSIF v_current_streak % 3 = 0 THEN v_points_to_award := 25; END IF;

    INSERT INTO daily_check_ins (user_id, streak, points_awarded) VALUES (v_user_id, v_current_streak, v_points_to_award);
    
    INSERT INTO user_points (user_id, current_balance, total_earned)
    VALUES (v_user_id, v_points_to_award, v_points_to_award)
    ON CONFLICT (user_id) DO UPDATE SET 
        current_balance = user_points.current_balance + EXCLUDED.current_balance,
        total_earned = user_points.total_earned + EXCLUDED.total_earned,
        updated_at = NOW();

    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_user_id, v_points_to_award, 'earn', 'Daily check-in streak: ' || v_current_streak);

    RETURN json_build_object('success', TRUE, 'streak', v_current_streak, 'points_awarded', v_points_to_award);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 6. CLAIM SPIN REWARD
DROP FUNCTION IF EXISTS public.claim_spin_reward(INT) CASCADE;
CREATE OR REPLACE FUNCTION public.claim_spin_reward(p_reward_points INT)
RETURNS JSON AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); END IF;
  PERFORM public.ensure_user_points(v_user_id);

  INSERT INTO spin_results (user_id, reward_points) VALUES (v_user_id, p_reward_points);

  IF p_reward_points > 0 THEN
    INSERT INTO user_points (user_id, current_balance, total_earned)
    VALUES (v_user_id, p_reward_points, p_reward_points)
    ON CONFLICT (user_id) DO UPDATE SET 
        current_balance = user_points.current_balance + EXCLUDED.current_balance,
        total_earned = user_points.total_earned + EXCLUDED.total_earned,
        updated_at = NOW();

    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_user_id, p_reward_points, 'earn', 'Spin Wheel Reward');
  END IF;

  RETURN json_build_object('success', true, 'points_awarded', p_reward_points);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
