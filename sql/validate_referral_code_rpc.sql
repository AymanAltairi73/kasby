-- ============================================================================
-- Referral code validation RPC (required for registration screen)
--
-- Why: profiles RLS only allows SELECT for auth.uid() = id, so anonymous
-- users registering cannot validate codes via a direct table query.
-- Also supports matching K-AB12CD (DB) vs KAB12CD (user input).
-- Run in Supabase Dashboard > SQL Editor
-- ============================================================================

CREATE OR REPLACE FUNCTION public.normalize_referral_code(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT upper(replace(trim(COALESCE(p_code, '')), '-', ''));
$$;

CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_normalized TEXT;
  v_referrer_id UUID;
  v_referrer_code TEXT;
  v_user_id UUID := auth.uid();
BEGIN
  v_normalized := public.normalize_referral_code(p_code);

  IF v_normalized = '' OR length(v_normalized) < 5 OR v_normalized !~ '^K[A-Z0-9]+$' THEN
    RETURN json_build_object('valid', false, 'reason', 'invalid_format');
  END IF;

  SELECT p.id, p.referral_code
  INTO v_referrer_id, v_referrer_code
  FROM profiles p
  WHERE public.normalize_referral_code(p.referral_code) = v_normalized
    AND COALESCE(p.status::text, 'active') NOT IN ('blocked', 'suspended')
  LIMIT 1;

  IF v_referrer_id IS NULL THEN
    RETURN json_build_object('valid', false, 'reason', 'not_found');
  END IF;

  IF v_user_id IS NOT NULL AND v_referrer_id = v_user_id THEN
    RETURN json_build_object('valid', false, 'reason', 'self_referral');
  END IF;

  RETURN json_build_object(
    'valid', true,
    'referrer_id', v_referrer_id,
    'referral_code', v_referrer_code
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_referral_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(TEXT) TO anon, authenticated;
