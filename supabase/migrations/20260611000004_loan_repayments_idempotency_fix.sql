-- ============================================================================
-- Fix repay_loan: add missing loan_repayments.idempotency_key + null-safe wallet
-- ============================================================================

ALTER TABLE public.loan_repayments
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

ALTER TABLE public.loan_repayments
  ADD COLUMN IF NOT EXISTS previous_remaining NUMERIC;

ALTER TABLE public.loan_repayments
  ADD COLUMN IF NOT EXISTS new_remaining NUMERIC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_loan_repayments_idempotency
  ON public.loan_repayments (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public.repay_loan(
  p_loan_id UUID,
  p_amount NUMERIC,
  p_type TEXT DEFAULT 'partial',
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_loan RECORD;
  v_wallet RECORD;
  v_user_id UUID;
  v_amount_to_pay NUMERIC := p_amount;
  v_existing_repayment_id UUID;
  v_available_balance NUMERIC;
BEGIN
  SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'القرض غير موجود');
  END IF;

  v_user_id := v_loan.user_id;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing_repayment_id
    FROM public.loan_repayments
    WHERE idempotency_key = p_idempotency_key
      AND loan_id = p_loan_id
    LIMIT 1;

    IF v_existing_repayment_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'message', 'تم تنفيذ هذه العملية مسبقاً',
        'repayment_id', v_existing_repayment_id
      );
    END IF;
  END IF;

  IF v_loan.status NOT IN ('active', 'partial_paid', 'overdue') THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'هذا القرض لا يقبل السداد حالياً حالته: ' || v_loan.status
    );
  END IF;

  SELECT * INTO v_wallet
  FROM public.wallets
  WHERE user_id = v_user_id
    AND currency = 'USD'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'المحفظة غير موجودة');
  END IF;

  v_available_balance := COALESCE(v_wallet.available_balance, 0);

  IF p_type = 'full' THEN
    v_amount_to_pay := v_loan.remaining_amount;
  END IF;

  IF v_amount_to_pay <= 0 THEN
    RETURN jsonb_build_object('success', false, 'message', 'مبلغ السداد غير صالح');
  END IF;

  IF v_amount_to_pay > v_loan.remaining_amount THEN
    RETURN jsonb_build_object('success', false, 'message', 'المبلغ المدفوع أكبر من المتبقي');
  END IF;

  IF v_available_balance < v_amount_to_pay THEN
    RETURN jsonb_build_object('success', false, 'message', 'رصيدك غير كافٍ في المحفظة المتاحة');
  END IF;

  UPDATE public.wallets
  SET available_balance = v_available_balance - v_amount_to_pay,
      updated_at = NOW()
  WHERE id = v_wallet.id;

  INSERT INTO public.transactions (
    user_id, wallet_id, type, amount, status, description, reference_id, idempotency_key
  ) VALUES (
    v_user_id,
    v_wallet.id,
    'loan_repayment',
    v_amount_to_pay,
    'completed',
    'سداد ' || CASE WHEN p_type = 'full' THEN 'كلي' ELSE 'جزئي' END || ' للقرض',
    p_loan_id::TEXT,
    p_idempotency_key
  );

  INSERT INTO public.loan_repayments (
    loan_id, user_id, amount, type, previous_remaining, new_remaining, idempotency_key
  ) VALUES (
    p_loan_id,
    v_user_id,
    v_amount_to_pay,
    p_type,
    v_loan.remaining_amount,
    v_loan.remaining_amount - v_amount_to_pay,
    p_idempotency_key
  );

  UPDATE public.loans
  SET
    paid_amount = paid_amount + v_amount_to_pay,
    remaining_amount = remaining_amount - v_amount_to_pay,
    status = CASE
      WHEN (remaining_amount - v_amount_to_pay) <= 0 THEN 'paid'
      ELSE 'partial_paid'
    END,
    paid_at = CASE
      WHEN (remaining_amount - v_amount_to_pay) <= 0 THEN NOW()
      ELSE paid_at
    END
  WHERE id = p_loan_id;

  INSERT INTO public.notifications (user_id, title, message)
  VALUES (
    v_user_id,
    'تم السداد بنجاح',
    'تم خصم $' || v_amount_to_pay || ' من رصيدك لسداد القرض. المتبقي: $'
      || (v_loan.remaining_amount - v_amount_to_pay)
  );

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تمت عملية السداد بنجاح',
    'remaining', v_loan.remaining_amount - v_amount_to_pay
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.repay_loan(UUID, NUMERIC, TEXT, TEXT) TO authenticated;
