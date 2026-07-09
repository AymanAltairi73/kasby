-- Resolve login email from phone for email+password sign-in via phone identifier.

CREATE OR REPLACE FUNCTION public.lookup_login_by_phone(p_phone text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, auth
AS $$
DECLARE
    v_digits text;
    v_with_plus text;
    v_email text;
BEGIN
    IF p_phone IS NULL OR trim(p_phone) = '' THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    v_digits := regexp_replace(trim(p_phone), '[^0-9]', '', 'g');
    IF v_digits = '' THEN
        RETURN jsonb_build_object('found', false);
    END IF;

    v_with_plus := '+' || v_digits;

    SELECT u.email
      INTO v_email
      FROM auth.users u
     WHERE regexp_replace(COALESCE(u.phone, ''), '[^0-9]', '', 'g') = v_digits
        OR regexp_replace(COALESCE(u.raw_user_meta_data->>'phone', ''), '[^0-9]', '', 'g') = v_digits
     LIMIT 1;

    IF v_email IS NOT NULL THEN
        RETURN jsonb_build_object('found', true, 'email', lower(trim(v_email)));
    END IF;

    SELECT u.email
      INTO v_email
      FROM public.profiles p
      JOIN auth.users u ON u.id = p.id
     WHERE regexp_replace(COALESCE(p.phone, ''), '[^0-9]', '', 'g') = v_digits
     LIMIT 1;

    RETURN jsonb_build_object(
        'found', v_email IS NOT NULL,
        'email', CASE WHEN v_email IS NOT NULL THEN lower(trim(v_email)) ELSE NULL END
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_login_by_phone(text) TO anon;
GRANT EXECUTE ON FUNCTION public.lookup_login_by_phone(text) TO authenticated;
