-- Fix search path to include extensions schema for crypt, gen_salt, and digest functions.

CREATE OR REPLACE FUNCTION public.fn_set_transaction_pin(p_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN must be exactly 6 digits');
  END IF;

  INSERT INTO public.user_transaction_security (user_id, pin_hash, failed_attempts, locked_until, updated_at)
  VALUES (v_user_id, extensions.crypt(p_pin, extensions.gen_salt('bf', 10)), 0, NULL, NOW())
  ON CONFLICT (user_id) DO UPDATE SET
    pin_hash = extensions.crypt(p_pin, extensions.gen_salt('bf', 10)),
    failed_attempts = 0,
    locked_until = NULL,
    updated_at = NOW();

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_verify_transaction_pin(p_pin TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_row public.user_transaction_security%ROWTYPE;
  v_remaining INT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized', 'retry', false);
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^\d{6}$' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid PIN format', 'retry', true);
  END IF;

  SELECT * INTO v_row FROM public.user_transaction_security WHERE user_id = v_user_id FOR UPDATE;

  IF NOT FOUND OR v_row.pin_hash IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'PIN not configured', 'retry', false);
  END IF;

  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > NOW() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'PIN temporarily locked',
      'locked', true,
      'locked_until', v_row.locked_until,
      'retry', false
    );
  END IF;

  IF v_row.pin_hash = extensions.crypt(p_pin, v_row.pin_hash) THEN
    UPDATE public.user_transaction_security
    SET failed_attempts = 0, locked_until = NULL, updated_at = NOW()
    WHERE user_id = v_user_id;

    RETURN jsonb_build_object('success', true);
  END IF;

  UPDATE public.user_transaction_security
  SET failed_attempts = failed_attempts + 1,
      locked_until = CASE
        WHEN failed_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes'
        ELSE locked_until
      END,
      updated_at = NOW()
  WHERE user_id = v_user_id
  RETURNING failed_attempts, locked_until INTO v_row.failed_attempts, v_row.locked_until;

  v_remaining := GREATEST(0, 5 - v_row.failed_attempts);

  IF v_row.locked_until IS NOT NULL AND v_row.locked_until > NOW() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Too many failed attempts',
      'locked', true,
      'locked_until', v_row.locked_until,
      'attempts_remaining', 0,
      'retry', false
    );
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'Incorrect PIN',
    'attempts_remaining', v_remaining,
    'retry', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reset_password_with_otp(
  p_phone TEXT,
  p_otp_code TEXT,
  p_new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
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
  v_hashed_input := encode(extensions.digest(p_otp_code, 'sha256'), 'hex');

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
  SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf'))
  WHERE id = v_user_id;

  -- 8. Cleanup used OTP
  DELETE FROM public.phone_otps WHERE id = v_otp_record.id;

  RETURN jsonb_build_object('success', true, 'message', 'Password updated successfully');
END;
$$;
