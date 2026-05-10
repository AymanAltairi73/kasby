-- ULTRA-ROBUST SECURE OTP SCHEMA FINALIZATION
-- This script ensures all required security columns exist, even if the table was created previously.

DO $$ 
BEGIN
    -- 1. Create table if it doesn't exist at all
    CREATE TABLE IF NOT EXISTS public.otp_verifications (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid()
    );

    -- 2. Add columns individually if they are missing
    
    -- code_hash (Handle legacy 'otp_hash' name)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='otp_hash') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='code_hash') THEN
        ALTER TABLE public.otp_verifications RENAME COLUMN otp_hash TO code_hash;
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='code_hash') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN code_hash TEXT NOT NULL;
    END IF;

    -- target
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='target') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN target VARCHAR NOT NULL;
    END IF;

    -- target_type
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='target_type') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN target_type VARCHAR NOT NULL DEFAULT 'phone';
    END IF;

    -- code_hash

    -- type (Handle legacy 'purpose' name)
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='purpose') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='type') THEN
        ALTER TABLE public.otp_verifications RENAME COLUMN purpose TO type;
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='type') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN type VARCHAR;
    END IF;

    -- user_id
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='user_id') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;
    ELSE
        ALTER TABLE public.otp_verifications ALTER COLUMN user_id SET NOT NULL;
    END IF;

    -- attempts
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='attempts') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN attempts INTEGER DEFAULT 0;
    END IF;

    -- max_attempts
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='max_attempts') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN max_attempts INTEGER DEFAULT 3;
    END IF;

    -- expires_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='expires_at') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (now() + interval '5 minutes');
    END IF;

    -- verified_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='verified_at') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN verified_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- used_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='used_at') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN used_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- created_at
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='otp_verifications' AND column_name='created_at') THEN
        ALTER TABLE public.otp_verifications ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    -- 3. Update the CHECK constraint
    ALTER TABLE public.otp_verifications DROP CONSTRAINT IF EXISTS otp_verifications_type_check;
    ALTER TABLE public.otp_verifications ADD CONSTRAINT otp_verifications_type_check 
    CHECK (type IN ('email_change', 'phone_change', 'password_reset', 'verification', 'signup'));

    -- 4. Add Indexes
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_otp_user_target') THEN
        CREATE INDEX idx_otp_user_target ON public.otp_verifications (user_id, target, type);
    END IF;

END $$;

-- 5. Enable RLS
ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own OTPs" ON public.otp_verifications;
CREATE POLICY "Users can view their own OTPs" 
ON public.otp_verifications FOR SELECT 
USING (auth.uid() = user_id);

-- 6. Reload schema cache for PostgREST
NOTIFY pgrst, 'reload schema';

COMMENT ON TABLE public.otp_verifications IS 'Hardened hashed OTP storage for profile updates and password resets.';
