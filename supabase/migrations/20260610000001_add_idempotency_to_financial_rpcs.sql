-- ============================================================================
-- ARCHITECTURAL IMPROVEMENT: Add idempotency to financial RPC functions
-- ============================================================================
-- This migration adds idempotency keys to create_transfer and repay_loan
-- functions to prevent duplicate transactions on network retries.
-- ============================================================================

-- 1. Add idempotency to create_transfer function
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.create_transfer(DECIMAL, TEXT, TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.create_transfer(
  p_amount NUMERIC,
  p_receiver_referral_code TEXT,
  p_transfer_type TEXT DEFAULT 'funds',
  p_idempotency_key TEXT DEFAULT NULL
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
  v_existing_tx_id UUID;
BEGIN
  IF v_sender_id IS NULL THEN RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); END IF;
  v_sender_wallet_id := public.ensure_user_wallet(v_sender_id);

  -- Check for existing transaction with same idempotency key
  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing_tx_id 
    FROM transactions 
    WHERE idempotency_key = p_idempotency_key AND user_id = v_sender_id 
    LIMIT 1;
    IF v_existing_tx_id IS NOT NULL THEN 
      RETURN json_build_object('success', true, 'message', 'تم تنفيذ هذه العملية مسبقاً', 'transaction_id', v_existing_tx_id); 
    END IF;
  END IF;

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

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id, idempotency_key)
  VALUES (v_sender_id, v_sender_wallet_id, 'transfer_out', p_amount, 'completed', 'تحويل إلى ' || v_receiver.full_name, v_receiver.id, p_idempotency_key)
  RETURNING id INTO v_tx_out_id;

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id, reference_id)
  VALUES (v_receiver.id, v_receiver_wallet_id, 'transfer_in', p_amount, 'completed', 'تحويل مستلم من مستخدم', v_sender_id, v_tx_out_id::TEXT);

  RETURN json_build_object('success', true, 'message', 'تم التحويل بنجاح', 'transaction_id', v_tx_out_id);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 2. Add idempotency to repay_loan function
DROP FUNCTION IF EXISTS public.repay_loan(UUID, NUMERIC, TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.repay_loan(
  p_loan_id UUID,
  p_amount NUMERIC,
  p_type TEXT DEFAULT 'partial',
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $_$
DECLARE
    v_loan RECORD;
    v_wallet RECORD;
    v_user_id UUID;
    v_amount_to_pay NUMERIC := p_amount;
    v_existing_repayment_id UUID;
BEGIN
    -- 1. Get Loan Data
    SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'القرض غير موجود');
    END IF;

    v_user_id := v_loan.user_id;

    -- Check for existing repayment with same idempotency key
    IF p_idempotency_key IS NOT NULL THEN
      SELECT id INTO v_existing_repayment_id 
      FROM loan_repayments 
      WHERE idempotency_key = p_idempotency_key AND loan_id = p_loan_id 
      LIMIT 1;
      IF v_existing_repayment_id IS NOT NULL THEN 
        RETURN jsonb_build_object('success', true, 'message', 'تم تنفيذ هذه العملية مسبقاً', 'repayment_id', v_existing_repayment_id); 
      END IF;
    END IF;

    -- 2. Validate Status
    IF v_loan.status NOT IN ('active', 'partial_paid', 'overdue') THEN
        RETURN jsonb_build_object('success', false, 'message', 'هذا القرض لا يقبل السداد حالياً حالته: ' || v_loan.status);
    END IF;

    -- 3. Get User Wallet (USD Available Only)
    SELECT * INTO v_wallet FROM public.wallets 
    WHERE user_id = v_user_id AND currency = 'USD' 
    FOR UPDATE;

    IF v_wallet.available_balance < v_amount_to_pay THEN
        RETURN jsonb_build_object('success', false, 'message', 'رصيدك غير كافٍ في المحفظة المتاحة');
    END IF;

    -- 4. Adjust if Full Repayment
    IF p_type = 'full' THEN
        v_amount_to_pay := v_loan.remaining_amount;
    END IF;

    -- 5. Validate Amount
    IF v_amount_to_pay > v_loan.remaining_amount THEN
        RETURN jsonb_build_object('success', false, 'message', 'المبلغ المدفوع أكبر من المتبقي');
    END IF;

    -- 6. Perform Atomic Updates
    
    -- A. Deduct from wallet
    UPDATE public.wallets 
    SET available_balance = available_balance - v_amount_to_pay,
        updated_at = NOW()
    WHERE id = v_wallet.id;

    -- B. Record Transaction
    INSERT INTO public.transactions (
        user_id, wallet_id, type, amount, status, description, reference_id, idempotency_key
    ) VALUES (
        v_user_id, v_wallet.id, 'loan_repayment', v_amount_to_pay, 'completed', 
        'سداد ' || CASE WHEN p_type = 'full' THEN 'كلي' ELSE 'جزئي' END || ' للقرض',
        p_loan_id::TEXT, p_idempotency_key
    );

    -- C. Record Repayment
    INSERT INTO public.loan_repayments (
        loan_id, user_id, amount, type, previous_remaining, new_remaining, idempotency_key
    ) VALUES (
        p_loan_id, v_user_id, v_amount_to_pay, p_type, 
        v_loan.remaining_amount, v_loan.remaining_amount - v_amount_to_pay, p_idempotency_key
    );

    -- D. Update Loan
    UPDATE public.loans 
    SET 
        paid_amount = paid_amount + v_amount_to_pay,
        remaining_amount = remaining_amount - v_amount_to_pay,
        status = CASE 
            WHEN (remaining_amount - v_amount_to_pay) <= 0 THEN 'paid'
            ELSE 'partial_paid'
        END,
        paid_at = CASE WHEN (remaining_amount - v_amount_to_pay) <= 0 THEN NOW() ELSE paid_at END
    WHERE id = p_loan_id;

    -- 7. Send Notification
    INSERT INTO public.notifications (user_id, title, message)
    VALUES (
        v_user_id, 
        'تم السداد بنجاح', 
        'تم خصم $' || v_amount_to_pay || ' من رصيدك لسداد القرض. المتبقي: $' || (v_loan.remaining_amount - v_amount_to_pay)
    );

    RETURN jsonb_build_object(
        'success', true, 
        'message', 'تمت عملية السداد بنجاح',
        'remaining', v_loan.remaining_amount - v_amount_to_pay
    );
END;
$_$;
