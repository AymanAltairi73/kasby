-- 🛠️ DB FIX: Clean up legacy constraints for OTP verifications
-- RUN THIS IN SUPABASE SQL EDITOR

DO $$ 
BEGIN
    -- 1. Drop the legacy constraint that refers to 'purpose' (even if column was renamed)
    ALTER TABLE public.otp_verifications 
    DROP CONSTRAINT IF EXISTS otp_verifications_purpose_check;

    -- 2. Drop the newer constraint if it exists to ensure a clean slate
    ALTER TABLE public.otp_verifications 
    DROP CONSTRAINT IF EXISTS otp_verifications_type_check;

    -- 3. Ensure the 'type' column exists (it should, but safety first)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='type') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN type VARCHAR;
    END IF;

    -- 4. Apply the unified constraint with all required purposes
    ALTER TABLE public.otp_verifications 
    ADD CONSTRAINT otp_verifications_type_check 
    CHECK (type IN ('email_change', 'phone_change', 'password_reset', 'verification', 'signup'));

    -- 5. Refresh schema cache
    NOTIFY pgrst, 'reload schema';
END $$;
