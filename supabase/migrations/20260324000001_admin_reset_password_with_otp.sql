-- ============================================================
-- RPC: admin_reset_password_with_otp
-- Description: Verifies the custom FCM OTP, identifies the user by profile phone,
-- and forcefully resets their password in auth.users securely.
-- Extends pgcrypto for password hashing.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.admin_reset_password_with_otp(
  p_phone TEXT,
  p_otp_code TEXT,
  p_new_password TEXT
)
RETURNS JSONB AS $$
DECLARE
  v_otp_record record;
  v_hashed_input TEXT;
  v_user_id UUID;
BEGIN
  -- Validate Input
  IF p_phone IS NULL OR p_otp_code IS NULL OR p_new_password IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'phone, otp_code, and new_password are required');
  END IF;

  IF length(p_new_password) < 6 THEN
    RETURN jsonb_build_object('success', false, 'error', 'Password must be at least 6 characters');
  END IF;

  -- 1. Hash incoming OTP using SHA-256 for comparison with the stored hash
  v_hashed_input := encode(digest(p_otp_code, 'sha256'), 'hex');

  -- 2. Find unverified OTP record
  SELECT * INTO v_otp_record
  FROM public.phone_otps
  WHERE phone_number = p_phone
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid verification attempt or expired.');
  END IF;

  -- 3. Check Brute Force Protection
  IF v_otp_record.attempts_count >= 5 THEN
    DELETE FROM public.phone_otps WHERE id = v_otp_record.id;
    RETURN jsonb_build_object('success', false, 'error', 'Too many failed attempts.');
  END IF;

  -- 4. Check if Expired
  IF v_otp_record.expires_at < now() THEN
    DELETE FROM public.phone_otps WHERE id = v_otp_record.id;
    RETURN jsonb_build_object('success', false, 'error', 'OTP code has expired.');
  END IF;

  -- 5. Compare Hash
  IF v_otp_record.otp_code != v_hashed_input THEN
    UPDATE public.phone_otps SET attempts_count = attempts_count + 1 WHERE id = v_otp_record.id;
    RETURN jsonb_build_object('success', false, 'error', 'Invalid OTP code');
  END IF;

  -- 6. Find User ID via profiles
  SELECT id INTO v_user_id
  FROM public.profiles
  WHERE phone = p_phone
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'No user registered with this phone number.');
  END IF;

  -- 7. Update Password in auth.users securely (Admin level via SECURITY DEFINER)
  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf'))
  WHERE id = v_user_id;

  -- 8. Cleanup used OTP
  DELETE FROM public.phone_otps WHERE id = v_otp_record.id;

  RETURN jsonb_build_object('success', true, 'message', 'Password updated successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
