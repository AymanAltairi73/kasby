-- ============================================================================
-- Kasby Migration: Regenerate Referral Codes to K-XXXXXX Format
-- Run this directly in the Supabase SQL Editor
-- ============================================================================

-- Step 1: Create a function to generate K-XXXXXX codes
CREATE OR REPLACE FUNCTION generate_referral_code_v2()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := '0123456789ABCDEF';
  result TEXT := 'K-';
  i INTEGER;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Update all existing users who have a referral code
-- This generates a new unique K-XXXXXX code for each user
DO $$
DECLARE
  user_record RECORD;
  new_code TEXT;
  is_unique BOOLEAN;
BEGIN
  FOR user_record IN SELECT id FROM profiles WHERE referral_code IS NOT NULL LOOP
    -- Loop until we get a unique code
    LOOP
      new_code := generate_referral_code_v2();
      SELECT NOT EXISTS(
        SELECT 1 FROM profiles WHERE referral_code = new_code
      ) INTO is_unique;
      EXIT WHEN is_unique;
    END LOOP;
    
    UPDATE profiles SET referral_code = new_code WHERE id = user_record.id;
  END LOOP;
END $$;

-- Step 3: Also generate codes for users who don't have one yet
DO $$
DECLARE
  user_record RECORD;
  new_code TEXT;
  is_unique BOOLEAN;
BEGIN
  FOR user_record IN SELECT id FROM profiles WHERE referral_code IS NULL LOOP
    LOOP
      new_code := generate_referral_code_v2();
      SELECT NOT EXISTS(
        SELECT 1 FROM profiles WHERE referral_code = new_code
      ) INTO is_unique;
      EXIT WHEN is_unique;
    END LOOP;
    
    UPDATE profiles SET referral_code = new_code WHERE id = user_record.id;
  END LOOP;
END $$;

-- Step 4: Verify the migration
SELECT id, referral_code FROM profiles ORDER BY created_at DESC LIMIT 20;

-- Step 5: Check for any remaining old-format codes
SELECT COUNT(*) AS old_format_count 
FROM profiles 
WHERE referral_code IS NOT NULL 
  AND referral_code NOT LIKE 'K-______';

-- Expected output: old_format_count = 0
