-- Resolve PostgREST PGRST203 ambiguity: consolidate repay_loan into one 4-param function.

DROP FUNCTION IF EXISTS public.repay_loan(uuid, numeric, text);
DROP FUNCTION IF EXISTS public.repay_loan(uuid, numeric, text, text);

CREATE OR REPLACE FUNCTION public.repay_loan(
  p_loan_id uuid,
  p_amount numeric,
  p_type text,
  p_idempotency_key text DEFAULT NULL
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
    v_existing RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'غير مسجل الدخول');
    END IF;

    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, amount INTO v_existing
        FROM public.transactions
        WHERE idempotency_key = p_idempotency_key
        LIMIT 1;

        IF FOUND THEN
            SELECT remaining_amount INTO v_remaining
            FROM public.loans
            WHERE id = p_loan_id;

            RETURN jsonb_build_object(
                'success', true,
                'message', 'تمت عملية السداد مسبقاً',
                'remaining', COALESCE(v_remaining, 0)
            );
        END IF;
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
        user_id, wallet_id, type, amount, status, description, reference_id, idempotency_key
    ) VALUES (
        v_user_id, v_wallet.id, 'loan_repayment', v_amount_to_pay, 'completed',
        'سداد ' || CASE WHEN p_type = 'full' THEN 'كلي' ELSE 'جزئي' END || ' للقرض',
        p_loan_id::TEXT,
        p_idempotency_key
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

GRANT ALL ON FUNCTION public.repay_loan(uuid, numeric, text, text) TO anon;
GRANT ALL ON FUNCTION public.repay_loan(uuid, numeric, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.repay_loan(uuid, numeric, text, text) TO service_role;
