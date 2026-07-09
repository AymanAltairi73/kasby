-- Allow users to submit KYC via RPC while keeping profile self-update guard intact.

CREATE OR REPLACE FUNCTION public.fn_guard_profile_self_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    IF auth.uid() = OLD.id AND NOT public.is_admin() THEN
        PERFORM public.fn_assert_user_can_write(OLD.id);

        IF NEW.kyc_status IS DISTINCT FROM OLD.kyc_status THEN
            IF current_setting('app.kyc_submit', true) IS DISTINCT FROM 'true' THEN
                RAISE EXCEPTION 'PERMISSION_DENIED: Cannot modify protected profile fields';
            END IF;
        END IF;

        IF NEW.status IS DISTINCT FROM OLD.status
           OR NEW.role IS DISTINCT FROM OLD.role
           OR NEW.account_tier IS DISTINCT FROM OLD.account_tier
           OR NEW.referral_code IS DISTINCT FROM OLD.referral_code
           OR NEW.referred_by IS DISTINCT FROM OLD.referred_by
           OR NEW.referred_by_id IS DISTINCT FROM OLD.referred_by_id
           OR NEW.status_reason IS DISTINCT FROM OLD.status_reason
           OR NEW.status_changed_at IS DISTINCT FROM OLD.status_changed_at
           OR NEW.status_changed_by IS DISTINCT FROM OLD.status_changed_by THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: Cannot modify protected profile fields';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_submit_kyc(p_full_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_doc_count int;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    PERFORM public.fn_assert_user_can_write(v_user_id);

    SELECT COUNT(*)::int INTO v_doc_count
    FROM kyc_documents
    WHERE user_id = v_user_id
      AND status = 'pending';

    IF v_doc_count < 3 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Upload all required KYC documents before submitting'
        );
    END IF;

    PERFORM set_config('app.kyc_submit', 'true', true);

    UPDATE profiles
    SET
        kyc_status = 'pending',
        full_name = COALESCE(NULLIF(trim(p_full_name), ''), full_name),
        updated_at = NOW()
    WHERE id = v_user_id
      AND kyc_status IN ('unverified', 'rejected');

    PERFORM set_config('app.kyc_submit', 'false', true);

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'KYC already submitted or account is verified'
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'KYC submitted for review');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_kyc(text) TO authenticated;
