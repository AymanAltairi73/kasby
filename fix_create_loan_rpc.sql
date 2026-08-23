-- Fix RPC function create_loan in Supabase database
-- Eliminates error: column "duration_months" of relation "loans" does not exist

CREATE OR REPLACE FUNCTION "public"."create_loan"(
  "p_amount" numeric,
  "p_duration_months" integer,
  "p_receive_as_points" boolean DEFAULT false
) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET search_path = public
    AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet_id UUID;
  v_wallet RECORD;
  v_interest_rate NUMERIC := 0.10;
  v_loan_id UUID;
BEGIN
  IF v_user_id IS NULL THEN 
    RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); 
  END IF;

  v_wallet_id := public.ensure_user_wallet(v_user_id);

  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;
  IF v_wallet.is_frozen THEN 
    RETURN json_build_object('success', false, 'error', 'المحفظة غير متاحة'); 
  END IF;

  IF COALESCE(v_wallet.invested_balance, 0) <= 0 THEN 
    RETURN json_build_object('success', false, 'error', 'يجب أن يكون لديك استثمارات نشطة'); 
  END IF;

  INSERT INTO loans (user_id, amount, interest_rate, paid_amount, status, repayment_date)
  VALUES (v_user_id, p_amount, v_interest_rate * 100, 0, 'pending', NOW() + (p_duration_months || ' months')::INTERVAL)
  RETURNING id INTO v_loan_id;

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, reference_id)
  VALUES (v_user_id, v_wallet_id, 'loan_disbursement', p_amount, 'pending', 'طلب قرض - ' || p_duration_months || ' شهر', v_loan_id::TEXT);

  RETURN json_build_object('success', true, 'loan_id', v_loan_id, 'message', 'تم تقديم طلب القرض بنجاح');
EXCEPTION WHEN OTHERS THEN 
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

ALTER FUNCTION "public"."create_loan"("p_amount" numeric, "p_duration_months" integer, "p_receive_as_points" boolean) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."create_loan"("p_amount" numeric, "p_duration_months" integer, "p_receive_as_points" boolean) TO "anon", "authenticated", "service_role";
