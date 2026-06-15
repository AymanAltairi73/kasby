CREATE OR REPLACE FUNCTION public.fn_admin_update_user_profile(
    p_target_user_id UUID,
    p_updates JSONB
) RETURNS JSONB
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public, auth
AS $fn$
DECLARE
    v_admin_id UUID := auth.uid();
    v_old RECORD;
    v_changed_fields TEXT[] := ARRAY[]::TEXT[];
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Admin access required';
    END IF;

    SELECT * INTO v_old FROM public.profiles WHERE id = p_target_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'NOT_FOUND: User profile not found';
    END IF;

    IF p_target_user_id = v_admin_id THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Cannot modify your own profile via admin RPC';
    END IF;

    UPDATE public.profiles SET
        full_name = COALESCE(NULLIF(p_updates->>'full_name', ''), full_name),
        email = COALESCE(NULLIF(p_updates->>'email', ''), email),
        phone = CASE WHEN jsonb_exists(p_updates, 'phone') THEN NULLIF(p_updates->>'phone', '') ELSE phone END,
        avatar_url = CASE WHEN jsonb_exists(p_updates, 'avatar_url') THEN NULLIF(p_updates->>'avatar_url', '') ELSE avatar_url END,
        country_code = COALESCE(NULLIF(p_updates->>'country_code', ''), country_code),
        country = COALESCE(NULLIF(p_updates->>'country', ''), country),
        province = COALESCE(p_updates->>'province', province),
        city = COALESCE(p_updates->>'city', city),
        address = COALESCE(p_updates->>'address', address),
        whatsapp = COALESCE(p_updates->>'whatsapp', whatsapp),
        telegram = COALESCE(p_updates->>'telegram', telegram),
        account_tier = COALESCE(NULLIF(p_updates->>'account_tier', ''), account_tier),
        kyc_status = COALESCE(NULLIF(p_updates->>'kyc_status', ''), kyc_status),
        updated_at = now()
    WHERE id = p_target_user_id;

    IF jsonb_exists(p_updates, 'email') AND NULLIF(p_updates->>'email', '') IS NOT NULL
       AND LOWER(p_updates->>'email') IS DISTINCT FROM LOWER(v_old.email) THEN
        UPDATE auth.users
        SET email = LOWER(p_updates->>'email'),
            email_confirmed_at = COALESCE(email_confirmed_at, now()),
            updated_at = now()
        WHERE id = p_target_user_id;
    END IF;

    IF jsonb_exists(p_updates, 'full_name')
       AND NULLIF(p_updates->>'full_name', '') IS DISTINCT FROM v_old.full_name THEN
        v_changed_fields := array_append(v_changed_fields, 'full_name');
    END IF;
    IF jsonb_exists(p_updates, 'email')
       AND NULLIF(p_updates->>'email', '') IS DISTINCT FROM v_old.email THEN
        v_changed_fields := array_append(v_changed_fields, 'email');
    END IF;
    IF jsonb_exists(p_updates, 'phone')
       AND NULLIF(p_updates->>'phone', '') IS DISTINCT FROM v_old.phone THEN
        v_changed_fields := array_append(v_changed_fields, 'phone');
    END IF;
    IF jsonb_exists(p_updates, 'avatar_url')
       AND NULLIF(p_updates->>'avatar_url', '') IS DISTINCT FROM v_old.avatar_url THEN
        v_changed_fields := array_append(v_changed_fields, 'avatar_url');
    END IF;
    IF jsonb_exists(p_updates, 'country_code')
       AND NULLIF(p_updates->>'country_code', '') IS DISTINCT FROM v_old.country_code THEN
        v_changed_fields := array_append(v_changed_fields, 'country_code');
    END IF;
    IF jsonb_exists(p_updates, 'country')
       AND NULLIF(p_updates->>'country', '') IS DISTINCT FROM v_old.country THEN
        v_changed_fields := array_append(v_changed_fields, 'country');
    END IF;
    IF jsonb_exists(p_updates, 'province')
       AND (p_updates->>'province') IS DISTINCT FROM v_old.province THEN
        v_changed_fields := array_append(v_changed_fields, 'province');
    END IF;
    IF jsonb_exists(p_updates, 'city')
       AND (p_updates->>'city') IS DISTINCT FROM v_old.city THEN
        v_changed_fields := array_append(v_changed_fields, 'city');
    END IF;
    IF jsonb_exists(p_updates, 'address')
       AND (p_updates->>'address') IS DISTINCT FROM v_old.address THEN
        v_changed_fields := array_append(v_changed_fields, 'address');
    END IF;
    IF jsonb_exists(p_updates, 'whatsapp')
       AND (p_updates->>'whatsapp') IS DISTINCT FROM v_old.whatsapp THEN
        v_changed_fields := array_append(v_changed_fields, 'whatsapp');
    END IF;
    IF jsonb_exists(p_updates, 'telegram')
       AND (p_updates->>'telegram') IS DISTINCT FROM v_old.telegram THEN
        v_changed_fields := array_append(v_changed_fields, 'telegram');
    END IF;
    IF jsonb_exists(p_updates, 'account_tier')
       AND NULLIF(p_updates->>'account_tier', '') IS DISTINCT FROM v_old.account_tier THEN
        v_changed_fields := array_append(v_changed_fields, 'account_tier');
    END IF;
    IF jsonb_exists(p_updates, 'kyc_status')
       AND NULLIF(p_updates->>'kyc_status', '') IS DISTINCT FROM v_old.kyc_status THEN
        v_changed_fields := array_append(v_changed_fields, 'kyc_status');
    END IF;

    PERFORM public.fn_write_user_management_audit(
        'admin_update_user_profile',
        p_target_user_id,
        jsonb_build_object('changed_fields', v_changed_fields, 'admin_id', v_admin_id)
    );

    PERFORM public.fn_create_notification(
        p_target_user_id,
        'تم تحديث بيانات حسابك',
        'قامت إدارة النظام بتحديث بيانات حسابك. يُرجى مراجعة الملف الشخصي للاطلاع على التغييرات.',
        'profile_updated',
        'profile',
        p_target_user_id::text,
        '/personalProfile',
        'user',
        'high'
    );

    RETURN (SELECT to_jsonb(p.*) FROM public.profiles p WHERE p.id = p_target_user_id);
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.fn_admin_update_user_profile(UUID, JSONB) TO authenticated, service_role;
