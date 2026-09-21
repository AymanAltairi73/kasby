-- Grant first free spin immediately on user registration
-- This ensures new users get 1 free spin instantly without waiting 24 hours

-- Add column to track if first free spin has been granted
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS first_free_spin_granted BOOLEAN DEFAULT FALSE;

-- Update handle_new_user trigger to grant first free spin on registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_referred_by_id UUID := NULL;
  v_referral_code  TEXT;
  v_input_code     TEXT;
BEGIN
  v_input_code := NEW.raw_user_meta_data ->> 'referred_by_code';

  IF v_input_code IS NOT NULL AND TRIM(v_input_code) != '' THEN
    SELECT id INTO v_referred_by_id
    FROM profiles
    WHERE UPPER(REPLACE(referral_code, '-', '')) = UPPER(REPLACE(TRIM(v_input_code), '-', ''))
      AND status NOT IN ('blocked', 'suspended')
    LIMIT 1;

    IF v_referred_by_id = NEW.id THEN
      v_referred_by_id := NULL;
    END IF;
  END IF;

  v_referral_code := 'K' || nextval('referral_code_seq')::TEXT;

  INSERT INTO profiles (
    id, full_name, email, phone, country_code, referral_code, referred_by,
    first_free_spin_granted, last_free_spin_at
  ) VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''), 'مستخدم جديد'),
    COALESCE(NULLIF(NEW.email, ''), NEW.raw_user_meta_data ->> 'email', ''),
    COALESCE(NULLIF(NEW.phone, ''), NEW.raw_user_meta_data ->> 'phone'),
    COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
    v_referral_code,
    v_referred_by_id,
    TRUE,  -- Grant first free spin immediately
    NOW() - INTERVAL '25 hours'  -- Set last_free_spin_at to 25 hours ago so first spin is available
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone,
    country_code = EXCLUDED.country_code,
    referral_code = COALESCE(profiles.referral_code, EXCLUDED.referral_code),
    referred_by = COALESCE(profiles.referred_by, EXCLUDED.referred_by),
    first_free_spin_granted = COALESCE(profiles.first_free_spin_granted, TRUE),
    last_free_spin_at = CASE 
      WHEN profiles.last_free_spin_at IS NULL THEN NOW() - INTERVAL '25 hours'
      ELSE profiles.last_free_spin_at 
    END;

  INSERT INTO wallets (user_id, currency) VALUES (NEW.id, 'USD')
  ON CONFLICT (user_id, currency) DO NOTHING;

  INSERT INTO user_points (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  IF v_referred_by_id IS NOT NULL THEN
    PERFORM process_registration_rewards(NEW.id, v_referred_by_id);
  END IF;

  INSERT INTO system_logs (actor_id, actor_role, action, entity_type, entity_id, details, severity)
  VALUES (
    NEW.id, 'user', 'user_registered', 'profile', NEW.id::TEXT,
    jsonb_build_object(
      'referred_by', v_referred_by_id,
      'referral_code', v_referral_code,
      'first_free_spin_granted', TRUE
    ),
    'info'
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'handle_new_user failed: %', SQLERRM;
  RETURN NEW;
END;
$$;

-- Ensure trigger exists on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Backfill: Grant first free spin to existing users who never spun
UPDATE public.profiles
SET 
  first_free_spin_granted = TRUE,
  last_free_spin_at = COALESCE(last_free_spin_at, NOW() - INTERVAL '25 hours')
WHERE first_free_spin_granted IS NULL OR first_free_spin_granted = FALSE;
