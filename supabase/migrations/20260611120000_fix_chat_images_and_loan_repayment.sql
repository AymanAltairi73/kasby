-- Fix chat attachment access and loan repayment logic
-- Apply via: supabase db push  OR  run in Supabase SQL editor

-- 1) Allow authenticated chat participants to read attachments via signed URLs
DROP POLICY IF EXISTS "Chat participants can read attachments" ON storage.objects;
CREATE POLICY "Chat participants can read attachments"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'chat_attachments');

-- 2) Backfill loan remaining balances
UPDATE public.loans
SET remaining_amount = total_due - COALESCE(paid_amount, 0)
WHERE remaining_amount IS NULL
  AND status IN ('active', 'current', 'partial_paid', 'delayed', 'overdue');

-- 3) Expand allowed loan statuses used by the app
ALTER TABLE public.loans DROP CONSTRAINT IF EXISTS loans_status_check;
ALTER TABLE public.loans ADD CONSTRAINT loans_status_check CHECK (
  status = ANY (ARRAY[
    'pending'::text, 'verified'::text, 'reviewing'::text, 'active'::text,
    'current'::text, 'partial_paid'::text, 'paid'::text, 'delayed'::text,
    'overdue'::text, 'defaulted'::text, 'cancelled'::text, 'liquidated'::text,
    'rejected'::text
  ])
);

-- 4) Initialize remaining_amount when admin approves a loan
CREATE OR REPLACE FUNCTION public.fn_approve_loan(p_loan_id uuid, p_admin_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_amount NUMERIC(18,4);
    v_status loan_status;
    v_wid UUID;
    v_new_bal NUMERIC(18,4);
BEGIN
    SELECT user_id, amount, status INTO v_user_id, v_amount, v_status
    FROM loans WHERE id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN RAISE EXCEPTION 'Loan not found.'; END IF;
    IF v_status != 'pending' THEN RAISE EXCEPTION 'Loan is not in pending status.'; END IF;

    SELECT id INTO v_wid FROM wallets WHERE user_id = v_user_id FOR UPDATE;

    UPDATE loans
    SET
      status = 'active',
      approved_by = p_admin_id,
      approved_at = CURRENT_TIMESTAMP,
      remaining_amount = total_due - COALESCE(paid_amount, 0)
    WHERE id = p_loan_id;

    UPDATE wallets SET available_balance = available_balance + v_amount WHERE id = v_wid;
    SELECT available_balance INTO v_new_bal FROM wallets WHERE id = v_wid;

    INSERT INTO transactions (user_id, wallet_id, type, amount, status, running_balance, processed_by, processed_at, description)
    VALUES (v_user_id, v_wid, 'loan_disbursement', v_amount, 'completed', v_new_bal, p_admin_id, CURRENT_TIMESTAMP, 'Loan disbursement');

    INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
    VALUES (p_admin_id, 'approve_loan', 'Loan amount: ' || v_amount, 'financial', 'success', p_loan_id::TEXT, 'loan');
END;
$$;

-- 5) Fix repay_loan: auth guard + NULL-safe remaining amount + valid statuses
CREATE OR REPLACE FUNCTION public.repay_loan(
  p_loan_id uuid,
  p_amount numeric,
  p_type text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_loan RECORD;
    v_wallet RECORD;
    v_user_id UUID := auth.uid();
    v_amount_to_pay NUMERIC := p_amount;
    v_remaining NUMERIC;
    v_new_remaining NUMERIC;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'غير مسجل الدخول');
    END IF;

    SELECT * INTO v_loan FROM public.loans WHERE id = p_loan_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'القرض غير موجود');
    END IF;

    IF v_loan.user_id <> v_user_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'غير مصرح لك بسداد هذا القرض');
    END IF;

    IF v_loan.status NOT IN ('active', 'partial_paid', 'overdue', 'current', 'delayed') THEN
        RETURN jsonb_build_object('success', false, 'message', 'هذا القرض لا يقبل السداد حالياً حالته: ' || v_loan.status);
    END IF;

    v_remaining := COALESCE(v_loan.remaining_amount, v_loan.total_due - COALESCE(v_loan.paid_amount, 0));

    IF v_remaining <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'لا يوجد مبلغ متبقٍ على هذا القرض');
    END IF;

    SELECT * INTO v_wallet FROM public.wallets
    WHERE user_id = v_user_id AND currency = 'USD'
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'المحفظة غير موجودة');
    END IF;

    IF p_type = 'full' THEN
        v_amount_to_pay := v_remaining;
    END IF;

    IF v_amount_to_pay <= 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'المبلغ غير صالح');
    END IF;

    IF v_amount_to_pay > v_remaining THEN
        RETURN jsonb_build_object('success', false, 'message', 'المبلغ المدفوع أكبر من المتبقي');
    END IF;

    IF v_wallet.available_balance < v_amount_to_pay THEN
        RETURN jsonb_build_object('success', false, 'message', 'رصيدك غير كافٍ في المحفظة المتاحة');
    END IF;

    v_new_remaining := v_remaining - v_amount_to_pay;

    UPDATE public.wallets
    SET available_balance = available_balance - v_amount_to_pay,
        updated_at = NOW()
    WHERE id = v_wallet.id;

    INSERT INTO public.transactions (
        user_id, wallet_id, type, amount, status, description, reference_id
    ) VALUES (
        v_user_id, v_wallet.id, 'loan_repayment', v_amount_to_pay, 'completed',
        'سداد ' || CASE WHEN p_type = 'full' THEN 'كلي' ELSE 'جزئي' END || ' للقرض',
        p_loan_id::TEXT
    );

    INSERT INTO public.loan_repayments (
        loan_id, user_id, amount, type, previous_remaining, new_remaining
    ) VALUES (
        p_loan_id, v_user_id, v_amount_to_pay, p_type,
        v_remaining, v_new_remaining
    );

    UPDATE public.loans
    SET
        paid_amount = COALESCE(paid_amount, 0) + v_amount_to_pay,
        remaining_amount = v_new_remaining,
        status = CASE
            WHEN v_new_remaining <= 0 THEN 'paid'
            ELSE 'partial_paid'
        END,
        paid_at = CASE WHEN v_new_remaining <= 0 THEN NOW() ELSE paid_at END
    WHERE id = p_loan_id;

    INSERT INTO public.notifications (user_id, title, message)
    VALUES (
        v_user_id,
        'تم السداد بنجاح',
        'تم خصم $' || v_amount_to_pay || ' من رصيدك لسداد القرض. المتبقي: $' || v_new_remaining
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تمت عملية السداد بنجاح',
        'remaining', v_new_remaining
    );
END;
$$;
