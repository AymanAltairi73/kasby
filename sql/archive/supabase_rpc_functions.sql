-- ============================================================
-- Kasby Financial RPC Functions
-- Run this in your Supabase SQL Editor
-- ============================================================

-- 0. HELPERS: AUTO-PROVISIONING
-- Ensure wallet and points exist for a user before any financial operation

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


-- 1. CREATE WITHDRAWAL
-- Creates a pending withdrawal request, validates balance, deducts from available_balance
-- ENFORCES only ONE pending withdrawal at a time.
DROP FUNCTION IF EXISTS create_withdrawal(NUMERIC, UUID, TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION create_withdrawal(
  p_amount NUMERIC,
  p_agent_id UUID,
  p_idempotency_key TEXT DEFAULT NULL,
  p_currency TEXT DEFAULT 'USD'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet RECORD;
  v_wallet_id UUID;
  v_transaction_id UUID;
  v_fee NUMERIC := 0;
BEGIN
  -- Check authentication
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- 1. Idempotency Check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id FROM transactions WHERE idempotency_key = p_idempotency_key;
    IF FOUND THEN
      RETURN json_build_object('success', true, 'transaction_id', v_transaction_id, 'message', 'تم تنفيذ هذه العملية مسبقاً');
    END IF;
  END IF;

  -- 2. Check for existing pending withdrawal
  IF EXISTS (
    SELECT 1 FROM transactions 
    WHERE user_id = v_user_id 
      AND type = 'withdrawal' 
      AND status = 'pending'
  ) THEN
    RETURN json_build_object('success', false, 'error', 'لديك طلب سحب قيد الانتظار بالفعل. يرجى الانتظار حتى معالجة الطلب الحالي.');
  END IF;

  -- 2. Ensure Wallet Exists
  v_wallet_id := public.ensure_user_wallet(v_user_id);

  -- Lock wallet row to prevent race conditions
  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;

  -- Check if wallet is frozen
  IF v_wallet.is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'المحفظة مجمدة. تواصل مع الدعم');
  END IF;

  -- Validate minimum amount
  IF p_amount < 10 THEN
    RETURN json_build_object('success', false, 'error', 'الحد الأدنى للسحب هو $10');
  END IF;

  -- Validate balance
  IF v_wallet.available_balance < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'الرصيد غير كافٍ');
  END IF;

  -- Create transaction record
  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency, status,
    running_balance, description, reference_id, idempotency_key
  ) VALUES (
    v_user_id, v_wallet.id, 'withdrawal', p_amount, v_fee, p_currency, 'pending',
    v_wallet.available_balance - p_amount, 'طلب سحب', p_agent_id::TEXT, p_idempotency_key
  )
  RETURNING id INTO v_transaction_id;

  -- Deduct from available balance, add to pending
  UPDATE wallets
  SET available_balance = available_balance - p_amount,
      pending_balance = pending_balance + p_amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  RETURN json_build_object(
    'success', true,
    'transaction_id', v_transaction_id,
    'message', 'تم تقديم طلب السحب بنجاح'
  );
END;
$$;

-- 1.1 APPROVE WITHDRAWAL
-- Admin approves a pending withdrawal request.
-- Clears pending_balance (it was already deducted from available).
DROP FUNCTION IF EXISTS approve_withdrawal(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION approve_withdrawal(
  p_txn_id UUID,
  p_admin_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_txn RECORD;
  v_wallet RECORD;
BEGIN
  -- 1. Fetch and Lock Transaction
  SELECT * INTO v_txn FROM transactions WHERE id = p_txn_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'المعاملة غير موجودة');
  END IF;

  IF v_txn.status != 'pending' OR v_txn.type != 'withdrawal' THEN
    RETURN json_build_object('success', false, 'error', 'هذه المعاملة غير متاحة للموافقة');
  END IF;

  -- 2. Lock Wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_txn.wallet_id FOR UPDATE;

  -- 3. Update Transaction
  UPDATE transactions
  SET status = 'completed',
      processed_by = p_admin_id,
      processed_at = NOW()
  WHERE id = p_txn_id;

  -- 4. Move Funds: clear pending (it's gone now)
  UPDATE wallets
  SET pending_balance = pending_balance - v_txn.amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  -- 5. Create Notification
  INSERT INTO notifications (
    user_id, title, message, type, target, target_user_id, status
  ) VALUES (
    v_txn.user_id, 'تم تنفيذ طلب السحب', 
    'تمت الموافقة على طلب السحب الخاص بك بمبلغ $' || v_txn.amount::TEXT,
    'success', 'user', v_txn.user_id, 'sent'
  );

  RETURN json_build_object('success', true, 'message', 'تمت الموافقة على السحب بنجاح.');
END;
$$;

-- 1.2 REJECT WITHDRAWAL
-- Admin rejects a pending withdrawal request.
-- Moves funds from pending_balance back to available_balance.
DROP FUNCTION IF EXISTS reject_withdrawal(UUID, UUID, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION reject_withdrawal(
  p_txn_id UUID,
  p_admin_id UUID,
  p_reason TEXT DEFAULT 'تم رفض طلب السحب من قبل الإدارة'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_txn RECORD;
  v_wallet RECORD;
BEGIN
  -- 1. Fetch and Lock Transaction
  SELECT * INTO v_txn FROM transactions WHERE id = p_txn_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'المعاملة غير موجودة');
  END IF;

  IF v_txn.status != 'pending' OR v_txn.type != 'withdrawal' THEN
    RETURN json_build_object('success', false, 'error', 'هذه المعاملة لا يمكن رفضها');
  END IF;

  -- 2. Lock Wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_txn.wallet_id FOR UPDATE;

  -- 3. Update Transaction
  UPDATE transactions
  SET status = 'rejected',
      rejection_reason = p_reason,
      processed_by = p_admin_id,
      processed_at = NOW()
  WHERE id = p_txn_id;

  -- 4. Move Funds: pending -> available
  UPDATE wallets
  SET pending_balance = pending_balance - v_txn.amount,
      available_balance = available_balance + v_txn.amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  -- 5. Create Notification
  INSERT INTO notifications (
    user_id, title, message, type, target, target_user_id, status
  ) VALUES (
    v_txn.user_id, 'تم رفض طلب السحب', 
    'تم رفض طلب السحب الخاص بك: ' || p_reason,
    'error', 'user', v_txn.user_id, 'sent'
  );

  RETURN json_build_object('success', true, 'message', 'تم رفض طلب السحب وإعادة المبلغ للمحفظة.');
END;
$$;

-- 2. CREATE TRANSFER
-- Transfers funds or points between users via referral code
DROP FUNCTION IF EXISTS create_transfer(NUMERIC, TEXT, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION create_transfer(
  p_amount NUMERIC,
  p_receiver_referral_code TEXT,
  p_transfer_type TEXT DEFAULT 'funds' -- 'funds' or 'points'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_receiver RECORD;
  v_sender_wallet RECORD;
  v_receiver_wallet RECORD;
  v_sender_wallet_id UUID;
  v_receiver_wallet_id UUID;
  v_tx_out_id UUID;
  v_tx_in_id UUID;
  v_currency TEXT := 'USD';
BEGIN
  IF v_sender_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'المبلغ غير صالح');
  END IF;

  -- 1. Ensure Sender Wallet
  v_sender_wallet_id := public.ensure_user_wallet(v_sender_id);
  
  -- Find receiver
  SELECT id, full_name INTO v_receiver FROM profiles WHERE referral_code = p_receiver_referral_code;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'كود الإحالة غير صالح');
  END IF;

  IF v_receiver.id = v_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'لا يمكنك التحويل لنفسك');
  END IF;

  -- 2. Ensure Receiver Wallet
  v_receiver_wallet_id := public.ensure_user_wallet(v_receiver.id);

  -- Lock sender wallet
  SELECT * INTO v_sender_wallet FROM wallets WHERE id = v_sender_wallet_id FOR UPDATE;

  IF v_sender_wallet.is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'المحفظة غير متاحة');
  END IF;

  -- Validate sender balance
  IF v_sender_wallet.available_balance < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'الرصيد غير كافٍ');
  END IF;

  -- Lock receiver wallet
  SELECT * INTO v_receiver_wallet FROM wallets WHERE id = v_receiver_wallet_id FOR UPDATE;

  -- Create transfer_out transaction
  INSERT INTO transactions (
    user_id, wallet_id, type, amount, currency, status,
    running_balance, counterpart_user_id, description
  ) VALUES (
    v_sender_id, v_sender_wallet.id, 'transfer_out', p_amount, v_currency, 'pending',
    v_sender_wallet.available_balance - p_amount, v_receiver.id,
    'تحويل إلى ' || v_receiver.full_name
  )
  RETURNING id INTO v_tx_out_id;

  -- Create transfer_in transaction
  INSERT INTO transactions (
    user_id, wallet_id, type, amount, currency, status,
    running_balance, counterpart_user_id, description, reference_id
  ) VALUES (
    v_receiver.id, v_receiver_wallet.id, 'transfer_in', p_amount, v_currency, 'pending',
    v_receiver_wallet.available_balance + p_amount, v_sender_id,
    'تحويل من مستخدم', v_tx_out_id::TEXT
  )
  RETURNING id INTO v_tx_in_id;

  -- Deduct from sender
  UPDATE wallets
  SET available_balance = available_balance - p_amount,
      pending_balance = pending_balance + p_amount,
      updated_at = NOW()
  WHERE id = v_sender_wallet.id;

  RETURN json_build_object(
    'success', true,
    'transaction_id', v_tx_out_id,
    'receiver_name', v_receiver.full_name,
    'message', 'تم إرسال طلب التحويل بنجاح'
  );
END;
$$;

-- 3. CREATE INVESTMENT
-- Creates investment from a plan, status starts as 'pending'.
-- Funds moved from available -> pending.
-- NO commission or profit calculation until approved.
CREATE OR REPLACE FUNCTION create_investment(
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
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- 1. Ensure Wallet Exists
  v_wallet_id := public.ensure_user_wallet(v_user_id);

  -- 2. Idempotency Check
  IF p_idempotency_key IS NOT NULL THEN
    SELECT reference_id::UUID INTO v_investment_id FROM transactions WHERE idempotency_key = p_idempotency_key AND type = 'investment';
    IF FOUND THEN
      RETURN json_build_object('success', true, 'investment_id', v_investment_id, 'message', 'تم تنفيذ هذه العملية مسبقاً');
    END IF;
  END IF;

  -- Fetch and validate investment plan
  SELECT * INTO v_plan
  FROM investment_plans
  WHERE id = p_plan_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'خطة الاستثمار غير متاحة');
  END IF;

  -- Validate amount against plan limits
  IF p_amount < v_plan.min_amount THEN
    RETURN json_build_object('success', false, 'error', 'المبلغ أقل من الحد الأدنى: ' || v_plan.min_amount);
  END IF;

  IF v_plan.max_amount IS NOT NULL AND p_amount > v_plan.max_amount THEN
    RETURN json_build_object('success', false, 'error', 'المبلغ أعلى من الحد الأقصى: ' || v_plan.max_amount);
  END IF;

  -- Lock wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;

  IF v_wallet.is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'المحفظة مجمدة');
  END IF;

  IF v_wallet.available_balance < p_amount THEN
    RETURN json_build_object('success', false, 'error', 'الرصيد غير كافٍ');
  END IF;

  -- Create investment transaction (Status: pending)
  INSERT INTO transactions (
    user_id, wallet_id, type, amount, currency, status,
    running_balance, description, idempotency_key
  ) VALUES (
    v_user_id, v_wallet.id, 'investment', p_amount, 'USD', 'pending',
    v_wallet.available_balance - p_amount,
    'طلب استثمار في خطة ' || v_plan.name_ar,
    p_idempotency_key
  )
  RETURNING id INTO v_tx_id;

  -- Create user_investments record (Status: pending)
  INSERT INTO user_investments (
    user_id, plan_id, transaction_id, amount, profit_percentage,
    expected_profit, status, start_date
  ) VALUES (
    v_user_id, p_plan_id, v_tx_id, p_amount, v_plan.profit_percentage,
    0, 'pending', NOW()
  )
  RETURNING id INTO v_investment_id;
  
  -- Update transaction with investment_id reference
  UPDATE transactions SET reference_id = v_investment_id::TEXT WHERE id = v_tx_id;

  -- Move funds: available → pending
  UPDATE wallets
  SET available_balance = available_balance - p_amount,
      pending_balance = pending_balance + p_amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  RETURN json_build_object(
    'success', true,
    'investment_id', v_investment_id,
    'transaction_id', v_tx_id,
    'message', 'تم تقديم طلب الاستثمار بنجاح، بانتظار موافقة الإدارة.'
  );
END;
$$;

-- 3.1 APPROVE INVESTMENT
-- Admin approves a pending investment.
-- Moves funds pending -> invested.
-- Calculates profit and triggers commission.
DROP FUNCTION IF EXISTS approve_investment(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION approve_investment(
  p_investment_id UUID,
  p_admin_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inv RECORD;
  v_wallet RECORD;
  v_plan RECORD;
  v_expected_profit NUMERIC;
  v_end_date TIMESTAMPTZ;
BEGIN
  -- Check if admin
  -- (Assuming an is_admin() check or admin_profiles check)
  
  -- 1. Fetch and Lock Investment
  SELECT * INTO v_inv FROM user_investments WHERE id = p_investment_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'الاستثمار غير موجود');
  END IF;
  
  IF v_inv.status != 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'هذا الاستثمار غير متاح للموافقة');
  END IF;

  -- 2. Fetch Plan
  SELECT * INTO v_plan FROM investment_plans WHERE id = v_inv.plan_id;
  
  -- 3. Lock Wallet
  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_inv.user_id AND currency = 'USD' FOR UPDATE;
  
  -- 4. Calculate profit and end date
  v_expected_profit := v_inv.amount * v_plan.profit_percentage / 100;
  v_end_date := NOW() + (COALESCE(v_plan.duration_days, 30) || ' days')::INTERVAL;

  -- 5. Update Investment
  UPDATE user_investments
  SET status = 'active',
      expected_profit = v_expected_profit,
      start_date = NOW(),
      end_date = v_end_date,
      approved_by = p_admin_id
  WHERE id = p_investment_id;

  -- 6. Update Transaction
  UPDATE transactions
  SET status = 'completed',
      processed_by = p_admin_id,
      processed_at = NOW()
  WHERE id = v_inv.transaction_id;

  -- 7. Move Funds: pending -> invested
  UPDATE wallets
  SET pending_balance = pending_balance - v_inv.amount,
      invested_balance = invested_balance + v_inv.amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  -- 8. Trigger commission (atomic)
  PERFORM process_referral_commission(v_inv.user_id, v_inv.amount, p_investment_id::TEXT);

  -- 9. Create Notification
  INSERT INTO notifications (
    user_id, title, message, type, target, target_user_id, status
  ) VALUES (
    v_inv.user_id, 'تم تفعيل استثمارك!', 
    'تمت الموافقة على استثمارك في خطة ' || v_plan.name_ar || ' بمبلغ $' || v_inv.amount::TEXT,
    'success', 'user', v_inv.user_id, 'sent'
  );

  RETURN json_build_object('success', true, 'message', 'تمت الموافقة على الاستثمار وتفعيله.');
END;
$$;

-- 3.2 REJECT INVESTMENT
-- Admin rejects a pending investment.
-- Moves funds pending -> available.
DROP FUNCTION IF EXISTS reject_investment(UUID, UUID, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION reject_investment(
  p_investment_id UUID,
  p_admin_id UUID,
  p_reason TEXT DEFAULT 'تم رفض الاستثمار من قبل الإدارة'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_inv RECORD;
  v_wallet RECORD;
BEGIN
  -- 1. Fetch and Lock Investment
  SELECT * INTO v_inv FROM user_investments WHERE id = p_investment_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'الاستثمار غير موجود');
  END IF;
  
  IF v_inv.status != 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'هذا الاستثمار لا يمكن رفضه');
  END IF;

  -- 2. Lock Wallet
  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_inv.user_id AND currency = 'USD' FOR UPDATE;
  
  -- 3. Update Investment
  UPDATE user_investments
  SET status = 'rejected'
  WHERE id = p_investment_id;

  -- 4. Update Transaction
  UPDATE transactions
  SET status = 'rejected',
      rejection_reason = p_reason,
      processed_by = p_admin_id,
      processed_at = NOW()
  WHERE id = v_inv.transaction_id;

  -- 5. Move Funds: pending -> available
  UPDATE wallets
  SET pending_balance = pending_balance - v_inv.amount,
      available_balance = available_balance + v_inv.amount,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  -- 6. Create Notification
  INSERT INTO notifications (
    user_id, title, message, type, target, target_user_id, status
  ) VALUES (
    v_inv.user_id, 'تم رفض طلب الاستثمار', 
    'عذراً، تم رفض طلب استثمارك: ' || p_reason,
    'error', 'user', v_inv.user_id, 'sent'
  );

  RETURN json_build_object('success', true, 'message', 'تم رفض الاستثمار وإعادة المبلغ للمحفظة.');
END;
$$;

-- 4. CREATE LOAN
-- Creates a loan request based on invested balance (max 40%)
DROP FUNCTION IF EXISTS create_loan(NUMERIC, INT, BOOLEAN) CASCADE;
CREATE OR REPLACE FUNCTION create_loan(
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
  v_interest_rate NUMERIC := 0.10; -- 10% monthly
  v_total_due NUMERIC;
  v_max_loan NUMERIC;
  v_min_loan NUMERIC;
  v_loan_id UUID;
  v_tx_id UUID;
  v_repayment_date TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- 1. Ensure Wallet Exists
  v_wallet_id := public.ensure_user_wallet(v_user_id);

  IF p_duration_months < 1 OR p_duration_months > 12 THEN
    RETURN json_build_object('success', false, 'error', 'مدة القرض غير صالحة');
  END IF;

  -- Lock wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;

  IF v_wallet.is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'المحفظة غير متاحة');
  END IF;

  -- Calculate limits based on invested balance
  v_max_loan := v_wallet.invested_balance * 0.40;
  v_min_loan := v_wallet.invested_balance * 0.10;

  IF v_wallet.invested_balance <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'يجب أن يكون لديك استثمارات نشطة للتقدم بطلب قرض');
  END IF;

  IF p_amount < v_min_loan THEN
    RETURN json_build_object('success', false, 'error', 'الحد الأدنى للقرض هو ' || v_min_loan);
  END IF;

  IF p_amount > v_max_loan THEN
    RETURN json_build_object('success', false, 'error', 'الحد الأقصى للقرض هو ' || v_max_loan);
  END IF;

  -- Check for existing active loans
  IF EXISTS (SELECT 1 FROM loans WHERE user_id = v_user_id AND status IN ('pending', 'current')) THEN
    RETURN json_build_object('success', false, 'error', 'لديك قرض قائم بالفعل');
  END IF;

  -- Calculate repayment
  v_total_due := p_amount + (p_amount * v_interest_rate * p_duration_months);
  v_repayment_date := NOW() + (p_duration_months || ' months')::INTERVAL;

  -- Create loan record
  INSERT INTO loans (
    user_id, amount, interest_rate, paid_amount, status, repayment_date
  ) VALUES (
    v_user_id, p_amount, v_interest_rate * 100, 0, 'pending', v_repayment_date
  )
  RETURNING id INTO v_loan_id;

  -- Create loan_disbursement transaction
  INSERT INTO transactions (
    user_id, wallet_id, type, amount, currency, status,
    running_balance, description, reference_id
  ) VALUES (
    v_user_id, v_wallet.id, 'loan_disbursement', p_amount, 'USD', 'pending',
    v_wallet.available_balance + p_amount,
    'طلب قرض - ' || p_duration_months || ' شهر',
    v_loan_id::TEXT
  )
  RETURNING id INTO v_tx_id;

  RETURN json_build_object(
    'success', true,
    'loan_id', v_loan_id,
    'transaction_id', v_tx_id,
    'total_due', v_total_due,
    'repayment_date', v_repayment_date,
    'message', 'تم تقديم طلب القرض بنجاح'
  );
END;
$$;

-- ============================================================
-- Gamification RPC Functions
-- ============================================================

-- 5. DAILY CHECK-IN
-- Awards bonus points for daily login, tracks streak
DROP FUNCTION IF EXISTS daily_check_in() CASCADE;
CREATE OR REPLACE FUNCTION daily_check_in()
RETURNS json AS $$
DECLARE
    v_user_id UUID;
    v_last_checkin TIMESTAMPTZ;
    v_current_streak INTEGER := 1;
    v_points_to_award INTEGER := 10; -- Base points
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    -- 0. Ensure Points Record Exists
    PERFORM public.ensure_user_points(v_user_id);

    -- 1. Check if already checked in today
    SELECT created_at INTO v_last_checkin
    FROM daily_check_ins
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE THEN
        RETURN json_build_object('success', FALSE, 'error', 'Already checked in today');
    END IF;

    -- 2. Calculate streak
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE - INTERVAL '1 day' THEN
        SELECT streak INTO v_current_streak
        FROM daily_check_ins
        WHERE user_id = v_user_id
        ORDER BY created_at DESC
        LIMIT 1;
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    -- 3. Calculate points (Bonus for streak milestones)
    v_points_to_award := 10;
    IF v_current_streak % 7 = 0 THEN
        v_points_to_award := 50;
    ELSIF v_current_streak % 3 = 0 THEN
        v_points_to_award := 25;
    END IF;

    -- 4. Record check-in
    INSERT INTO daily_check_ins (user_id, streak, points_awarded)
    VALUES (v_user_id, v_current_streak, v_points_to_award);

    -- 5. Award points
    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_user_id, v_points_to_award, 'earn', 'Daily check-in streak: ' || v_current_streak);

    INSERT INTO user_points (user_id, total_earned)
    VALUES (v_user_id, v_points_to_award)
    ON CONFLICT (user_id) DO UPDATE
    SET total_earned = user_points.total_earned + EXCLUDED.total_earned,
        updated_at = CURRENT_TIMESTAMP;

    RETURN json_build_object(
        'success', TRUE,
        'streak', v_current_streak,
        'points_awarded', v_points_to_award,
        'message', 'Check-in successful! + ' || v_points_to_award || ' points'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. CLAIM SPIN REWARD
-- Records spin result and awards points
DROP FUNCTION IF EXISTS claim_spin_reward(INT) CASCADE;
CREATE OR REPLACE FUNCTION claim_spin_reward(
  p_reward_points INT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- 0. Ensure Points Record Exists
  PERFORM public.ensure_user_points(v_user_id);

  IF p_reward_points < 0 THEN
    RETURN json_build_object('success', false, 'error', 'قيمة غير صالحة');
  END IF;

  -- 1. Record spin result
  INSERT INTO spin_results (user_id, reward_points)
  VALUES (v_user_id, p_reward_points);

  -- 2. Award points if > 0
  IF p_reward_points > 0 THEN
    -- Update user_points
    INSERT INTO user_points (user_id, total_earned)
    VALUES (v_user_id, p_reward_points)
    ON CONFLICT (user_id) DO UPDATE
    SET total_earned = user_points.total_earned + EXCLUDED.total_earned,
        updated_at = NOW();

    -- Record in point_history
    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_user_id, p_reward_points, 'earn', 'Spin Wheel Reward');
  END IF;

  RETURN json_build_object(
    'success', true,
    'points_awarded', p_reward_points,
    'message', CASE WHEN p_reward_points > 0
      THEN 'تهانينا! حصلت على ' || p_reward_points || ' نقطة'
      ELSE 'حظ أوفر في المرة القادمة'
    END
  );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- 7. BUY SUBSCRIPTION
-- Deducts funds and activates premium tier
DROP FUNCTION IF EXISTS buy_subscription(account_tier, BOOLEAN) CASCADE;
CREATE OR REPLACE FUNCTION buy_subscription(
    p_tier account_tier,
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
    -- 1. Validate user
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    -- 1.1 Ensure Wallet Exists
    v_wallet_id := public.ensure_user_wallet(v_user_id);

    -- 2. Determine amount and duration
    IF p_is_yearly THEN
        v_amount := 89.00;
        v_duration := INTERVAL '1 year';
    ELSE
        v_amount := 9.00;
        v_duration := INTERVAL '1 month';
    END IF;

    -- 3. Lock wallet and check balance
    SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;

    IF v_wallet.available_balance < v_amount THEN
        RETURN json_build_object('success', FALSE, 'error', 'Insufficient balance');
    END IF;

    -- 4. Deduct funds
    UPDATE wallets
    SET available_balance = available_balance - v_amount,
        updated_at = NOW()
    WHERE id = v_wallet_id;

    -- 5. Create transaction record
    INSERT INTO transactions (user_id, wallet_id, type, amount, status, description)
    VALUES (v_user_id, v_wallet_id, 'fee', v_amount, 'completed', 'Premium Subscription: ' || p_tier::TEXT)
    RETURNING id INTO v_new_txn_id;

    -- 6. Update user tier
    UPDATE profiles
    SET account_tier = p_tier,
        updated_at = NOW()
    WHERE id = v_user_id;

    -- 7. Record subscription
    INSERT INTO subscriptions (user_id, tier, is_yearly, amount, end_date, payment_transaction_id)
    VALUES (v_user_id, p_tier, p_is_yearly, v_amount, NOW() + v_duration, v_new_txn_id);

    RETURN json_build_object(
        'success', TRUE,
        'message', 'Subscription activated successfully',
        'tier', p_tier,
        'end_date', (NOW() + v_duration)
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
