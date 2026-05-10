-- ==============================================================================
-- KASBY LOGGING STANDARDIZATION — Restore system_logs
-- Date: 2026-04-19
-- Purpose: Ensures the system_logs table exists (critical for backend triggers)
--          and migrates data from the temporary activity_logs table.
-- ==============================================================================

BEGIN;

-- 1. Create system_logs if missing (Schema aligned with Production Master)
CREATE TABLE IF NOT EXISTS public.system_logs (
    id          UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    actor_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    actor_role  TEXT NOT NULL DEFAULT 'user',
    action      TEXT NOT NULL,
    entity_type TEXT DEFAULT 'system',
    entity_id   TEXT,
    details     JSONB DEFAULT '{}'::jsonb,
    severity    TEXT DEFAULT 'info',
    ip_address  TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.system_logs ENABLE ROW LEVEL SECURITY;

-- 2. Migrate data from activity_logs if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'activity_logs' AND schemaname = 'public') THEN
        RAISE NOTICE 'Migrating data from activity_logs to system_logs...';
        
        -- Copy what we can (matching columns)
        INSERT INTO public.system_logs (actor_id, action, details, severity, actor_role, entity_type, created_at)
        SELECT 
            actor_id, 
            action, 
            details::jsonb, -- Ensure it's jsonb
            severity, 
            COALESCE(actor_role, 'user'), 
            COALESCE(entity_type, 'system'), 
            created_at
        FROM public.activity_logs
        ON CONFLICT DO NOTHING;
        
        -- Option: Drop activity_logs after migration (Uncomment after verification)
        -- DROP TABLE public.activity_logs;
    END IF;
END $$;

-- 3. RLS POLICIES
-- Allow authenticated users to insert their own logs
DROP POLICY IF EXISTS "Users can insert own logs" ON public.system_logs;
CREATE POLICY "Users can insert own logs" 
    ON public.system_logs FOR INSERT 
    WITH CHECK (auth.uid() = actor_id OR auth.uid() IS NULL); -- Allow anonymous for auth flows

-- Allow admins to see all logs
DROP POLICY IF EXISTS "Admins view all logs" ON public.system_logs;
CREATE POLICY "Admins view all logs" 
    ON public.system_logs FOR SELECT 
    USING (EXISTS (
        SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
    ));

-- 4. GRANTS
GRANT INSERT ON public.system_logs TO authenticated, anon, service_role;
GRANT SELECT ON public.system_logs TO authenticated, service_role;

COMMIT;

-- ==============================================================================
-- END OF LOGGING STANDARDIZATION
-- ==============================================================================
