-- Admin KYC approval, user block/unblock, and is_admin() hardening.

-- ─── Harden admin detection (profiles.role OR active admin_profiles) ─────────

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) OR EXISTS (
    SELECT 1
    FROM public.admin_profiles
    WHERE id = auth.uid() AND COALESCE(is_active, TRUE) = TRUE
  );
END;
$$;

-- ─── Block / unblock users ───────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_admin_block_user(
  p_target_user_id UUID,
  p_reason TEXT,
  p_admin_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id UUID := COALESCE(p_admin_id, auth.uid());
  v_reason TEXT := NULLIF(TRIM(p_reason), '');
  v_profile RECORD;
BEGIN
  IF NOT public.is_admin() AND p_admin_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Admin access required';
  END IF;

  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'VALIDATION_ERROR: Block reason is required';
  END IF;

  SELECT id, status
    INTO v_profile
  FROM public.profiles
  WHERE id = p_target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: User not found';
  END IF;

  UPDATE public.profiles
  SET
    status = 'blocked',
    status_reason = v_reason,
    status_changed_by = v_admin_id,
    updated_at = NOW()
  WHERE id = p_target_user_id;

  INSERT INTO public.activity_logs (actor_id, actor_role, action, entity_type, entity_id, details)
  VALUES (
    v_admin_id,
    'admin',
    'admin_block_user',
    'profile',
    p_target_user_id::TEXT,
    jsonb_build_object('reason', v_reason)
  );

  RETURN jsonb_build_object('success', TRUE, 'status', 'blocked');
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_unblock_user(
  p_target_user_id UUID,
  p_admin_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id UUID := COALESCE(p_admin_id, auth.uid());
  v_profile RECORD;
BEGIN
  IF NOT public.is_admin() AND p_admin_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHORIZED: Admin access required';
  END IF;

  SELECT id, status
    INTO v_profile
  FROM public.profiles
  WHERE id = p_target_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NOT_FOUND: User not found';
  END IF;

  UPDATE public.profiles
  SET
    status = 'active',
    status_reason = NULL,
    status_changed_by = v_admin_id,
    updated_at = NOW()
  WHERE id = p_target_user_id;

  INSERT INTO public.activity_logs (actor_id, actor_role, action, entity_type, entity_id, details)
  VALUES (
    v_admin_id,
    'admin',
    'admin_unblock_user',
    'profile',
    p_target_user_id::TEXT,
    jsonb_build_object('previous_status', v_profile.status)
  );

  RETURN jsonb_build_object('success', TRUE, 'status', 'active');
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_block_user(UUID, TEXT, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_admin_unblock_user(UUID, UUID) TO authenticated, service_role;

-- ─── KYC approval hardening ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_admin_approve_user_kyc(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_now TIMESTAMPTZ := NOW();
  v_profile RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  SELECT id, kyc_status
    INTO v_profile
  FROM public.profiles
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'User not found');
  END IF;

  UPDATE public.kyc_documents
  SET
    status = 'verified',
    reviewed_by = v_admin_id,
    reviewed_at = v_now,
    rejection_reason = NULL
  WHERE user_id = p_user_id AND status = 'pending';

  UPDATE public.profiles
  SET
    kyc_status = 'verified',
    kyc_rejection_reason = NULL,
    kyc_verified_at = v_now,
    kyc_verified_by = v_admin_id,
    account_tier = CASE WHEN account_tier = 'free' THEN 'verified' ELSE account_tier END,
    updated_at = v_now
  WHERE id = p_user_id;

  INSERT INTO public.activity_logs (actor_id, actor_role, action, entity_type, entity_id, details)
  VALUES (
    v_admin_id,
    'admin',
    'admin_approve_user_kyc',
    'profile',
    p_user_id::TEXT,
    jsonb_build_object('approved_at', v_now, 'previous_kyc_status', v_profile.kyc_status)
  );

  RETURN jsonb_build_object('success', TRUE, 'kyc_status', 'verified');
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'error', SQLERRM
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_approve_user_kyc(UUID) TO authenticated, service_role;

-- Align fn_admin_set_kyc_status with hardened is_admin + profile check.
-- Must DROP first: prior migration defined RETURNS VOID; cannot change via CREATE OR REPLACE.
DROP FUNCTION IF EXISTS public.fn_admin_set_kyc_status(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.fn_admin_set_kyc_status(
  p_user_id UUID,
  p_status TEXT,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Unauthorized');
  END IF;

  IF p_status NOT IN ('unverified', 'pending', 'verified', 'rejected') THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid KYC status');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'User not found');
  END IF;

  UPDATE public.profiles
  SET
    kyc_status = p_status,
    kyc_rejection_reason = CASE
      WHEN p_status = 'rejected' THEN COALESCE(NULLIF(TRIM(p_reason), ''), kyc_rejection_reason)
      ELSE NULL
    END,
    updated_at = NOW()
  WHERE id = p_user_id;

  RETURN jsonb_build_object('success', TRUE, 'kyc_status', p_status);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_set_kyc_status(UUID, TEXT, TEXT) TO authenticated, service_role;
