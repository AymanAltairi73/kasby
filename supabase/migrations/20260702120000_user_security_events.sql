-- User security activity timeline for Security Center
CREATE TABLE IF NOT EXISTS public.user_security_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'success',
    device_name TEXT,
    device_type TEXT,
    platform TEXT,
    browser TEXT,
    ip_address TEXT,
    app_version TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_security_events_user_created
    ON public.user_security_events (user_id, created_at DESC);

ALTER TABLE public.user_security_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own security events"
    ON public.user_security_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users insert own security events"
    ON public.user_security_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT ON public.user_security_events TO authenticated;
