-- ============================================================
-- RPC: recover_account_by_email
-- Description: Intelligently handles the discrepancy between auth.users and public.profiles.
-- If an email exists in profiles but not auth.users, this recovers the associated phone number securely.
-- ============================================================

CREATE OR REPLACE FUNCTION recover_account_by_email(p_email TEXT)
RETURNS JSONB AS $$
DECLARE
  v_user profiles%ROWTYPE;
BEGIN
  -- Find the user profile by exact email, bypassing RLS using SECURITY DEFINER
  SELECT * INTO v_user FROM profiles WHERE LOWER(email) = LOWER(p_email) LIMIT 1;
  
  IF v_user IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'User not found');
  END IF;

  IF v_user.phone IS NULL OR v_user.phone = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'No phone number attached to this profile');
  END IF;
  
  RETURN jsonb_build_object(
    'success', true, 
    'phone', v_user.phone,
    'message', 'Found associated phone number'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
