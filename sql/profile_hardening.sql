-- ──────────────────────────────────────────────────────────────────
-- PROFILE HARDENING: OTP SECURITY & ATOMIC UPDATES
-- ──────────────────────────────────────────────────────────────────

-- 1. Create a secure OTP verifications table
CREATE TABLE IF NOT EXISTS public.otp_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target VARCHAR NOT NULL, -- The new email or phone number
    code_hash TEXT NOT NULL, -- Hashed code for security
    type VARCHAR NOT NULL CHECK (type IN ('email_change', 'phone_change')),
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS (Security)
ALTER TABLE public.otp_verifications ENABLE ROW LEVEL SECURITY;

-- Only users can see their own OTP records (though mostly handled by Edge Functions)
CREATE POLICY "Users can view their own OTPs" 
ON public.otp_verifications FOR SELECT 
USING (auth.uid() = user_id);

-- 2. Add Unique Constraints to Profiles (Ensure data integrity)
-- Since your system is append-only (FORBIDDEN: Transactions are append-only), 
-- we cannot DELETE duplicates. Instead, we RENAME them to resolve the conflict.
DO $$
BEGIN
    -- 2.1 RESOLVE DUPLICATES (KEEPING NEWEST)
    -- Rename older duplicate emails by appending a suffix
    UPDATE public.profiles p1
    SET email = p1.email || '.dup.' || EXTRACT(EPOCH FROM now())::text
    FROM public.profiles p2
    WHERE p1.created_at < p2.created_at
      AND p1.email = p2.email;

    -- Rename older duplicate phones by appending a suffix
    UPDATE public.profiles p1
    SET phone = p1.phone || '.dup.' || EXTRACT(EPOCH FROM now())::text
    FROM public.profiles p2
    WHERE p1.created_at < p2.created_at
      AND p1.phone = p2.phone
      AND p1.phone IS NOT NULL;

    -- 2.2 CREATE UNIQUE INDEXES
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'unique_profile_email') THEN
        CREATE UNIQUE INDEX unique_profile_email ON public.profiles (email);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'unique_profile_phone') THEN
        CREATE UNIQUE INDEX unique_profile_phone ON public.profiles (phone);
    END IF;
END $$;

-- 3. Audit Logging (Ensure consistency with existing activity_logs)
-- Verify if activity_logs exists, otherwise create it as a fallback
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    details TEXT,
    severity TEXT DEFAULT 'info',
    actor_role TEXT,
    entity_type TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.otp_verifications IS 'Hardened OTP tracking for sensitive profile changes.';
