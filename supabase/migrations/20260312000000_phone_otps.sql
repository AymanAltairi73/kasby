-- Create phone_otps table
CREATE TABLE IF NOT EXISTS public.phone_otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number TEXT NOT NULL,
    otp_code TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    verified BOOLEAN DEFAULT false,
    attempts_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_phone_otps_phone_number ON public.phone_otps(phone_number);
CREATE INDEX IF NOT EXISTS idx_phone_otps_expires_at ON public.phone_otps(expires_at);

-- Function to clean up expired OTPs
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS VOID AS $$
BEGIN
    DELETE FROM public.phone_otps WHERE expires_at < now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a table for rate limiting OTP requests
CREATE TABLE IF NOT EXISTS public.otp_rate_limits (
    phone_number TEXT PRIMARY KEY,
    request_count INTEGER DEFAULT 1,
    last_request_at TIMESTAMPTZ DEFAULT now(),
    window_start_at TIMESTAMPTZ DEFAULT now()
);

-- Function to check and update rate limits
-- Returns true if allowed, false if rate limited
CREATE OR REPLACE FUNCTION public.check_otp_rate_limit(p_phone_number TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_now TIMESTAMPTZ := now();
    v_window_interval INTERVAL := INTERVAL '10 minutes';
    v_max_requests INTEGER := 3;
    v_record RECORD;
BEGIN
    SELECT * INTO v_record FROM public.otp_rate_limits WHERE phone_number = p_phone_number;

    IF NOT FOUND THEN
        INSERT INTO public.otp_rate_limits (phone_number, request_count, last_request_at, window_start_at)
        VALUES (p_phone_number, 1, v_now, v_now);
        RETURN TRUE;
    END IF;

    -- Reset window if 10 minutes passed
    IF v_now > v_record.window_start_at + v_window_interval THEN
        UPDATE public.otp_rate_limits
        SET request_count = 1,
            last_request_at = v_now,
            window_start_at = v_now
        WHERE phone_number = p_phone_number;
        RETURN TRUE;
    END IF;

    -- Check request count
    IF v_record.request_count < v_max_requests THEN
        UPDATE public.otp_rate_limits
        SET request_count = request_count + 1,
            last_request_at = v_now
        WHERE phone_number = p_phone_number;
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable Row Level Security (RLS)
ALTER TABLE public.phone_otps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_rate_limits ENABLE ROW LEVEL SECURITY;

-- Note: Policies will be restrictive as these tables should only be accessed via Service Role or Edge Functions
CREATE POLICY "Allow service role access to phone_otps" ON public.phone_otps
    USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role access to otp_rate_limits" ON public.otp_rate_limits
    USING (auth.role() = 'service_role');
