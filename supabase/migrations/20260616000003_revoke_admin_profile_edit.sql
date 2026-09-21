-- Revoke admin ability to arbitrarily edit user profile data.
-- Admins retain read access; status/KYC changes go through dedicated RPCs only.

DROP FUNCTION IF EXISTS public.fn_admin_update_user_profile(uuid, jsonb);

DROP POLICY IF EXISTS "Admins have full access to profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;

CREATE POLICY "Admins can read all profiles"
  ON public.profiles
  FOR SELECT
  USING (public.is_admin());

-- KYC status changes (verification workflow — not general profile editing)
CREATE OR REPLACE FUNCTION public.fn_admin_set_kyc_status(
  p_user_id uuid,
  p_status text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Admin access required';
  END IF;

  IF p_status NOT IN ('unverified', 'pending', 'verified', 'rejected') THEN
    RAISE EXCEPTION 'Invalid KYC status: %', p_status;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  UPDATE public.profiles
  SET kyc_status = p_status,
      updated_at = NOW()
  WHERE id = p_user_id;

  IF p_status = 'verified' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read)
    VALUES (
      p_user_id,
      'توثيق الحساب',
      'تم توثيق حسابك بنجاح! يمكنك الآن الاستمتاع بكافة مميزات التطبيق.',
      'kyc_approved',
      false
    );
  ELSIF p_status = 'rejected' THEN
    INSERT INTO public.notifications (user_id, title, message, type, is_read)
    VALUES (
      p_user_id,
      'تنبيه التوثيق',
      COALESCE(
        NULLIF(trim(p_reason), ''),
        'نعتذر، تم رفض طلب التوثيق الخاص بك. يرجى مراجعة البيانات والمحاولة مرة أخرى.'
      ),
      'kyc_rejected',
      false
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_set_kyc_status(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_admin_set_kyc_status(uuid, text, text) TO authenticated;
