-- fn_submit_kyc must set app.kyc_submit so trg_guard_profile_self_update
-- permits the kyc_status transition to pending.
CREATE OR REPLACE FUNCTION public.fn_submit_kyc(p_full_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Not authenticated');
  END IF;

  PERFORM set_config('app.kyc_submit', 'true', true);

  UPDATE public.profiles
  SET
    kyc_status = 'pending',
    kyc_rejection_reason = NULL,
    full_name = COALESCE(NULLIF(TRIM(p_full_name), ''), full_name),
    updated_at = NOW()
  WHERE id = v_user_id;

  RETURN jsonb_build_object('success', TRUE, 'kyc_status', 'pending');
END;
$function$;
