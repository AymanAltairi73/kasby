-- RPC: lookup_login_by_phone
-- Resolves a profile email from a phone number for password-based login.
-- Returns only whether a match was found and the associated email (if any).
-- Does not expose passwords or other sensitive profile data.

CREATE OR REPLACE FUNCTION public.lookup_login_by_phone(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_digits TEXT;
BEGIN
  IF p_phone IS NULL OR trim(p_phone) = '' THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  v_digits := regexp_replace(trim(p_phone), '[^0-9]', '', 'g');

  IF v_digits = '' THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  SELECT *
  INTO v_profile
  FROM public.profiles
  WHERE regexp_replace(coalesce(phone, ''), '[^0-9]', '', 'g') = v_digits
  LIMIT 1;

  IF v_profile IS NULL THEN
    RETURN jsonb_build_object('found', false);
  END IF;

  IF v_profile.email IS NULL OR trim(v_profile.email) = '' THEN
    RETURN jsonb_build_object('found', true, 'email', null);
  END IF;

  RETURN jsonb_build_object(
    'found', true,
    'email', lower(trim(v_profile.email))
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.lookup_login_by_phone(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.lookup_login_by_phone(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_login_by_phone(TEXT) TO service_role;
