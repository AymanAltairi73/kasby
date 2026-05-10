-- SQL Migration: Fix RLS for system_logs during auth flows
-- When a user is logged out (e.g., during password reset), auth.uid() is null.
-- But SupabaseService.logActivity might still try to log errors with that null ID or an expired ID.
-- This policy allows inserts if the actor_id matches the authenticated user, 
-- or allows anonymous inserts if you prefer (though usually we just bypass RLS for system_logs inserts).

-- Option A: Allow any authenticated or anon user to INSERT into system_logs (simplest for logging)
CREATE POLICY "Allow anyone to insert system logs" 
ON public.system_logs 
FOR INSERT 
TO public 
WITH CHECK (true);

-- Option B (If you want to restrict it):
-- DROP POLICY IF EXISTS "Users can insert own logs" ON public.system_logs;
-- CREATE POLICY "Users can insert own logs" 
-- ON public.system_logs 
-- FOR INSERT 
-- TO authenticated 
-- WITH CHECK (auth.uid() = actor_id);
