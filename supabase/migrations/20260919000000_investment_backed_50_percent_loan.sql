-- ============================================================================
-- Migration: 50% Investment-Backed Loan System
-- File: supabase/migrations/20260919000000_investment_backed_50_percent_loan.sql
-- ============================================================================

-- 1. Ensure loan_max_percentage is configured in app_config (default 0.50)
INSERT INTO public.app_config (key, value, description)
VALUES ('loan_max_percentage', '0.50', 'Maximum borrowing percentage relative to active invested balance')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = NOW();

-- 2. Authoritative create_loan RPC function
CREATE OR REPLACE FUNCTION public.create_loan(
  p_amount numeric,
  p_duration_months integer,
  p_receive_as_points boolean DEFAULT false
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet_id UUID;
  v_wallet RECORD;
  v_loan_max_percentage NUMERIC := 0.50;
  v_interest_rate NUMERIC := 0.10;
  v_config_val TEXT;
  v_total_capacity NUMERIC(18, 4);
  v_existing_exposure NUMERIC(18, 4);
  v_remaining_capacity NUMERIC(18, 4);
  v_total_due NUMERIC(18, 4);
  v_loan_id UUID;
  v_tx_id UUID;
  v_repayment_date TIMESTAMPTZ;
BEGIN
  -- 1. Authentication check
  IF v_user_id IS NULL THEN 
    RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); 
  END IF;

  -- 2. Input validation
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'المبلغ غير صالح');
  END IF;

  IF p_duration_months IS NULL OR p_duration_months < 1 OR p_duration_months > 12 THEN
    RETURN json_build_object('success', false, 'error', 'مدة القرض غير صالحة');
  END IF;

  -- 3. System level check: system_settings.pause_loans
  IF EXISTS (SELECT 1 FROM system_settings WHERE pause_loans = TRUE LIMIT 1) THEN
    RETURN json_build_object('success', false, 'error', 'نظام القروض متوقف مؤقتاً حالياً');
  END IF;

  -- 4. Concurrency protection: Lock user wallet row for update
  v_wallet_id := public.ensure_user_wallet(v_user_id);

  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'المحفظة غير موجودة');
  END IF;

  IF v_wallet.is_frozen THEN 
    RETURN json_build_object('success', false, 'error', 'المحفظة غير متاحة'); 
  END IF;

  -- 5. Active Investment Check (Aggregated active investment principal)
  IF COALESCE(v_wallet.invested_balance, 0) <= 0 THEN 
    RETURN json_build_object('success', false, 'error', 'يجب أن يكون لديك استثمارات نشطة للتأهل للقرض'); 
  END IF;

  -- 6. Fetch authoritative loan percentage from app_config (default 0.50)
  SELECT value INTO v_config_val FROM app_config WHERE key = 'loan_max_percentage';
  IF v_config_val IS NOT NULL THEN
    v_loan_max_percentage := COALESCE(NULLIF(v_config_val, '')::NUMERIC, 0.50);
  END IF;
  IF v_loan_max_percentage <= 0 THEN
    v_loan_max_percentage := 0.50;
  END IF;

  -- 7. Fetch authoritative loan interest rate from app_config (default 0.10)
  SELECT value INTO v_config_val FROM app_config WHERE key = 'loan_interest_rate';
  IF v_config_val IS NOT NULL THEN
    v_interest_rate := COALESCE(NULLIF(v_config_val, '')::NUMERIC, 0.10);
  END IF;

  -- 8. Compute Total Borrowing Capacity (50% of aggregated active investment balance)
  v_total_capacity := ROUND(v_wallet.invested_balance * v_loan_max_percentage, 2);

  -- 9. Compute Existing Exposure (Pending + Active loans, excluding paid/rejected/cancelled)
  SELECT COALESCE(SUM(GREATEST(0, amount - COALESCE(paid_amount, 0))), 0)
  INTO v_existing_exposure
  FROM loans
  WHERE user_id = v_user_id
    AND status IN ('pending', 'approved', 'active', 'current', 'partial_paid', 'delayed', 'overdue');

  -- 10. Compute Remaining Borrowing Capacity
  v_remaining_capacity := GREATEST(0, v_total_capacity - v_existing_exposure);

  -- 11. Validate requested amount against remaining borrowing capacity
  IF p_amount > v_remaining_capacity THEN
    RETURN json_build_object(
      'success', false,
      'error', 'المبلغ المطلوب (' || p_amount || ' USD) يتجاوز سقف القرض المتاح لك حالياً (' || v_remaining_capacity || ' USD)',
      'total_capacity', v_total_capacity,
      'existing_exposure', v_existing_exposure,
      'remaining_capacity', v_remaining_capacity
    );
  END IF;

  -- 12. Calculate repayment terms
  v_total_due := p_amount + (p_amount * v_interest_rate * p_duration_months);
  v_repayment_date := NOW() + (p_duration_months || ' months')::INTERVAL;

  -- 13. Create loan record
  INSERT INTO loans (
    user_id,
    amount,
    interest_rate,
    total_due,
    paid_amount,
    remaining_amount,
    status,
    loan_date,
    repayment_date
  ) VALUES (
    v_user_id,
    p_amount,
    v_interest_rate * 100,
    v_total_due,
    0,
    v_total_due,
    'pending',
    NOW(),
    v_repayment_date
  )
  RETURNING id INTO v_loan_id;

  -- 14. Create pending transaction record
  INSERT INTO transactions (
    user_id,
    wallet_id,
    type,
    amount,
    currency,
    status,
    running_balance,
    description,
    reference_id
  ) VALUES (
    v_user_id,
    v_wallet.id,
    'loan_disbursement',
    p_amount,
    'USD',
    'pending',
    v_wallet.available_balance + p_amount,
    'طلب قرض - ' || p_duration_months || ' شهر',
    v_loan_id::TEXT
  )
  RETURNING id INTO v_tx_id;

  -- 15. Return comprehensive success response
  RETURN json_build_object(
    'success', true,
    'loan_id', v_loan_id,
    'transaction_id', v_tx_id,
    'amount', p_amount,
    'total_due', v_total_due,
    'repayment_date', v_repayment_date,
    'total_capacity', v_total_capacity,
    'existing_exposure', v_existing_exposure + p_amount,
    'remaining_capacity', v_remaining_capacity - p_amount,
    'message', 'تم تقديم طلب القرض بنجاح'
  );

EXCEPTION WHEN OTHERS THEN 
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

ALTER FUNCTION public.create_loan(numeric, integer, boolean) OWNER TO postgres;
GRANT ALL ON FUNCTION public.create_loan(numeric, integer, boolean) TO anon, authenticated, service_role;
