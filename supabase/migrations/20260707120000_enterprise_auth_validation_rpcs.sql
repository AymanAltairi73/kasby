-- Enterprise auth validation RPCs: account existence, availability checks, profile provisioning.
-- Fixes recover_account_by_email (must not require phone for email reset existence check).
-- Minimal JSON responses to reduce PII exposure on anon calls.

-- ─── Account existence (forgot password) ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.recover_account_by_email(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_profile_id uuid;
BEGIN
  IF p_email IS NULL OR trim(p_email) = '' THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE lower(email) = lower(trim(p_email))
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.recover_account_by_phone(p_phone text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_profile_id uuid;
  v_phone text := trim(p_phone);
BEGIN
  IF v_phone IS NULL OR v_phone = '' THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE phone = v_phone
     OR phone = regexp_replace(v_phone, '^\+', '')
     OR ('+' || phone) = v_phone
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── Availability checks (registration / profile update) ─────────────────────

CREATE OR REPLACE FUNCTION public.fn_check_email_available(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email text := lower(trim(p_email));
  v_uid uuid := auth.uid();
  v_owner uuid;
BEGIN
  IF v_email IS NULL OR v_email = '' OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RETURN jsonb_build_object('available', false);
  END IF;

  SELECT id INTO v_owner
  FROM public.profiles
  WHERE lower(email) = v_email
  LIMIT 1;

  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('available', true);
  END IF;

  IF v_uid IS NOT NULL AND v_owner = v_uid THEN
    RETURN jsonb_build_object('available', true);
  END IF;

  RETURN jsonb_build_object('available', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_check_phone_available(p_phone text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_phone text := trim(p_phone);
  v_uid uuid := auth.uid();
  v_owner uuid;
BEGIN
  IF v_phone IS NULL OR v_phone = '' OR length(regexp_replace(v_phone, '[^0-9]', '', 'g')) < 7 THEN
    RETURN jsonb_build_object('available', false);
  END IF;

  SELECT id INTO v_owner
  FROM public.profiles
  WHERE phone = v_phone
     OR phone = regexp_replace(v_phone, '^\+', '')
     OR ('+' || phone) = v_phone
  LIMIT 1;

  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('available', true);
  END IF;

  IF v_uid IS NOT NULL AND v_owner = v_uid THEN
    RETURN jsonb_build_object('available', true);
  END IF;

  RETURN jsonb_build_object('available', false);
END;
$$;

-- ─── Post-OTP profile provisioning ───────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_ensure_user_profile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_user auth.users%ROWTYPE;
  v_created boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = v_uid) THEN
    RETURN jsonb_build_object('success', true, 'created', false);
  END IF;

  SELECT * INTO v_user FROM auth.users WHERE id = v_uid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    phone,
    country_code
  )
  VALUES (
    v_uid,
    coalesce(v_user.email, ''),
    coalesce(v_user.raw_user_meta_data->>'full_name', ''),
    coalesce(v_user.phone, v_user.raw_user_meta_data->>'phone'),
    v_user.raw_user_meta_data->>'country_code'
  )
  ON CONFLICT (id) DO NOTHING;

  GET DIAGNOSTICS v_created = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'created', v_created > 0);
END;
$$;

-- ─── Grants ──────────────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.recover_account_by_email(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.recover_account_by_phone(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_check_email_available(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_check_phone_available(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_ensure_user_profile() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.recover_account_by_email(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.recover_account_by_phone(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_check_email_available(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_check_phone_available(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_ensure_user_profile() TO authenticated;
