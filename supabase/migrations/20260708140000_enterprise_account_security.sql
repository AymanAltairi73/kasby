-- Enterprise account security: deleted account registry, auth validation hardening,
-- and self-service deletion support.

-- ─── Deleted account registry ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.deleted_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  original_user_id UUID NOT NULL,
  email TEXT,
  email_normalized TEXT,
  phone TEXT,
  phone_normalized TEXT,
  deletion_type TEXT NOT NULL CHECK (deletion_type IN ('admin', 'self')),
  deleted_by UUID,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_deleted_accounts_email_norm
  ON public.deleted_accounts (email_normalized)
  WHERE email_normalized IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_deleted_accounts_phone_norm
  ON public.deleted_accounts (phone_normalized)
  WHERE phone_normalized IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_deleted_accounts_user_id
  ON public.deleted_accounts (original_user_id);

ALTER TABLE public.deleted_accounts ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.deleted_accounts FROM PUBLIC, anon, authenticated;

-- ─── Phone normalization helper ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_normalize_phone_identifier(p_phone TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(
    regexp_replace(COALESCE(trim(p_phone), ''), '[^0-9]', '', 'g'),
    ''
  );
$$;

-- ─── Record deleted account before purge ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_record_deleted_account(
  p_user_id UUID,
  p_deletion_type TEXT,
  p_deleted_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email TEXT;
  v_phone TEXT;
  v_email_norm TEXT;
  v_phone_norm TEXT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'user_id is required');
  END IF;

  IF p_deletion_type NOT IN ('admin', 'self') THEN
    RETURN jsonb_build_object('success', false, 'message', 'invalid deletion_type');
  END IF;

  SELECT email, phone
    INTO v_email, v_phone
  FROM public.profiles
  WHERE id = p_user_id;

  IF v_email IS NULL AND v_phone IS NULL THEN
    SELECT email, phone
      INTO v_email, v_phone
    FROM auth.users
    WHERE id = p_user_id;
  END IF;

  v_email_norm := NULLIF(lower(trim(COALESCE(v_email, ''))), '');
  v_phone_norm := public.fn_normalize_phone_identifier(v_phone);

  INSERT INTO public.deleted_accounts (
    original_user_id,
    email,
    email_normalized,
    phone,
    phone_normalized,
    deletion_type,
    deleted_by
  )
  SELECT
    p_user_id,
    NULLIF(trim(COALESCE(v_email, '')), ''),
    v_email_norm,
    NULLIF(trim(COALESCE(v_phone, '')), ''),
    v_phone_norm,
    p_deletion_type,
    p_deleted_by
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.deleted_accounts d
    WHERE d.original_user_id = p_user_id
       OR (v_email_norm IS NOT NULL AND d.email_normalized = v_email_norm)
       OR (v_phone_norm IS NOT NULL AND d.phone_normalized = v_phone_norm)
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_record_deleted_account(UUID, TEXT, UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_record_deleted_account(UUID, TEXT, UUID) TO service_role;

-- ─── Deleted account lookup (anon-safe, minimal PII) ─────────────────────────

CREATE OR REPLACE FUNCTION public.fn_check_deleted_account(
  p_email TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email_norm TEXT := NULLIF(lower(trim(COALESCE(p_email, ''))), '');
  v_phone_norm TEXT := public.fn_normalize_phone_identifier(p_phone);
  v_row public.deleted_accounts%ROWTYPE;
BEGIN
  IF v_email_norm IS NOT NULL THEN
    SELECT * INTO v_row
    FROM public.deleted_accounts
    WHERE email_normalized = v_email_norm
    ORDER BY deleted_at DESC
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'deleted', true,
        'deletion_type', v_row.deletion_type
      );
    END IF;
  END IF;

  IF v_phone_norm IS NOT NULL THEN
    SELECT * INTO v_row
    FROM public.deleted_accounts
    WHERE phone_normalized = v_phone_norm
       OR phone_normalized = regexp_replace(v_phone_norm, '^0+', '')
    ORDER BY deleted_at DESC
    LIMIT 1;

    IF FOUND THEN
      RETURN jsonb_build_object(
        'deleted', true,
        'deletion_type', v_row.deletion_type
      );
    END IF;
  END IF;

  RETURN jsonb_build_object('deleted', false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_check_deleted_account(TEXT, TEXT) TO anon, authenticated, service_role;

-- ─── Account existence (password recovery) ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.recover_account_by_email(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email TEXT := lower(trim(p_email));
  v_deleted JSONB;
  v_profile_id UUID;
BEGIN
  IF v_email IS NULL OR v_email = '' THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  v_deleted := public.fn_check_deleted_account(p_email := v_email);
  IF COALESCE((v_deleted->>'deleted')::boolean, false) THEN
    RETURN jsonb_build_object(
      'success', false,
      'deleted', true,
      'deletion_type', v_deleted->>'deletion_type'
    );
  END IF;

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE lower(email) = v_email
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.recover_account_by_phone(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_phone TEXT := trim(p_phone);
  v_deleted JSONB;
  v_profile_id UUID;
BEGIN
  IF v_phone IS NULL OR v_phone = '' THEN
    RETURN jsonb_build_object('success', false);
  END IF;

  v_deleted := public.fn_check_deleted_account(p_phone := v_phone);
  IF COALESCE((v_deleted->>'deleted')::boolean, false) THEN
    RETURN jsonb_build_object(
      'success', false,
      'deleted', true,
      'deletion_type', v_deleted->>'deletion_type'
    );
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

-- ─── Availability checks (registration / profile update) ───────────────────

CREATE OR REPLACE FUNCTION public.fn_check_email_available(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_email TEXT := lower(trim(p_email));
  v_uid UUID := auth.uid();
  v_owner UUID;
  v_deleted JSONB;
BEGIN
  IF v_email IS NULL OR v_email = '' OR v_email !~ '^[^@]+@[^@]+\.[^@]+$' THEN
    RETURN jsonb_build_object('available', false);
  END IF;

  v_deleted := public.fn_check_deleted_account(p_email := v_email);
  IF COALESCE((v_deleted->>'deleted')::boolean, false) THEN
    RETURN jsonb_build_object(
      'available', false,
      'reason', 'deleted',
      'deletion_type', v_deleted->>'deletion_type'
    );
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

CREATE OR REPLACE FUNCTION public.fn_check_phone_available(p_phone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_phone TEXT := trim(p_phone);
  v_uid UUID := auth.uid();
  v_owner UUID;
  v_deleted JSONB;
BEGIN
  IF v_phone IS NULL OR v_phone = '' OR length(regexp_replace(v_phone, '[^0-9]', '', 'g')) < 7 THEN
    RETURN jsonb_build_object('available', false);
  END IF;

  v_deleted := public.fn_check_deleted_account(p_phone := v_phone);
  IF COALESCE((v_deleted->>'deleted')::boolean, false) THEN
    RETURN jsonb_build_object(
      'available', false,
      'reason', 'deleted',
      'deletion_type', v_deleted->>'deletion_type'
    );
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

GRANT EXECUTE ON FUNCTION public.recover_account_by_email(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.recover_account_by_phone(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_check_email_available(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_check_phone_available(TEXT) TO anon, authenticated, service_role;
