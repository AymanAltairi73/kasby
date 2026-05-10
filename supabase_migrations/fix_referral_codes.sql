-- =============================================
-- Phase 2: Referral System Enhancement
-- =============================================

-- 1. Ensure referral_code column exists and satisfies the new K-XXXXXX format
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'referral_code') THEN
        ALTER TABLE profiles ADD COLUMN referral_code TEXT;
    END IF;
END $$;

-- 2. Add unique constraint (if not already present)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_referral_code_key') THEN
        ALTER TABLE profiles ADD CONSTRAINT profiles_referral_code_key UNIQUE (referral_code);
    END IF;
END $$;

-- 3. Function to generate a random K-XXXXXX referral code (6 chars)
CREATE OR REPLACE FUNCTION generate_referral_code() RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Excluded I, O, 0, 1 for clarity
  result TEXT;
  code_len INTEGER := 6;
  i INTEGER;
BEGIN
  LOOP
    result := 'K-';
    FOR i IN 1..code_len LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    
    -- Check uniqueness
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE referral_code = result) THEN
        RETURN result;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. Update existing users who don't have a referral code
DO $$
DECLARE
    r RECORD;
    new_code TEXT;
BEGIN
    FOR r IN SELECT id FROM profiles WHERE referral_code IS NULL OR referral_code = '' LOOP
        new_code := generate_referral_code();
        UPDATE profiles SET referral_code = new_code WHERE id = r.id;
    END LOOP;
END $$;
