-- Migration: Add referral_code to profiles and set up automatic generation

-- 1. Add referral_code column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='referral_code') THEN
        ALTER TABLE profiles ADD COLUMN referral_code TEXT UNIQUE;
    END IF;
END $$;

-- 2. Create function to generate a unique referral code
CREATE OR REPLACE FUNCTION generate_unique_referral_code()
RETURNS TEXT AS $$
DECLARE
    new_code TEXT;
    done BOOLEAN := FALSE;
BEGIN
    WHILE NOT done LOOP
        -- Generate a code like K-XXXX-XXXX
        new_code := 'K-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' || upper(substring(md5(random()::text) from 5 for 4));
        
        -- Check for collision
        IF NOT EXISTS (SELECT 1 FROM profiles WHERE referral_code = new_code) THEN
            done := TRUE;
        END IF;
    END LOOP;
    RETURN new_code;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- 3. Update existing users who don't have a referral code
UPDATE profiles 
SET referral_code = generate_unique_referral_code()
WHERE referral_code IS NULL;

-- 4. Make referral_code NOT NULL (optional, but recommended if everyone should have one)
-- ALTER TABLE profiles ALTER COLUMN referral_code SET NOT NULL;

-- 5. Create trigger function to assign referral code on insert
CREATE OR REPLACE FUNCTION fn_assign_referral_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.referral_code IS NULL THEN
        NEW.referral_code := generate_unique_referral_code();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Create the trigger
DROP TRIGGER IF EXISTS trg_assign_referral_code ON profiles;
CREATE TRIGGER trg_assign_referral_code
    BEFORE INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION fn_assign_referral_code();
