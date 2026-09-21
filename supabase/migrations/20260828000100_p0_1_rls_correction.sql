-- ==============================================================================
-- KASBY P0-1 CORRECTION : scope RLS policies to authenticated + re-affirm RLS
-- ==============================================================================
-- Purpose (minimal corrective follow-up to 20260828000000_p0_1_...sql):
--   1) The original policies were created WITHOUT a TO clause, so they default
--      to TO public and are evaluated for the anonymous role too. This caused
--      anon SELECT on profiles to raise 42501 "permission denied for function
--      is_related_profile" (the profiles_select_related policy calls
--      is_related_profile, whose EXECUTE is revoked from anon).
--   2) Live behavioral evidence showed anon SELECT on notifications still
--      returned all rows, indicating notifications RLS was not effectively
--      filtering anonymous access.
--
-- This migration ONLY:
--   * Re-affirms Row Level Security is ENABLED on public.profiles and
--     public.notifications (idempotent).
--   * Drops and recreates the same 7 policies, explicitly scoped TO
--     authenticated, so anonymous is excluded from evaluating them.
--   * Re-asserts EXECUTE grants on the helper so authenticated retains it.
--
-- It does NOT modify, redesign, or touch any financial logic/table/RPC,
-- any balance/KSP/store/daily-profit code, fn_create_notification,
-- fn_create_bulk_notification, FCM, Realtime, or notification business logic.
-- It does NOT UPDATE, INSERT-except-own-flow, DELETE, or TRUNCATE any data.
--
-- IDEMPOTENT / REVERSIBLE / BACKWARD COMPATIBLE / NO DATA LOSS.
-- Safe to re-run.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1) Re-affirm RLS is enabled on both tables (no-op if already enabled).
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 2) Helper EXECUTE grants (idempotent): authenticated retains execute; anon/others denied.
-- ------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.is_related_profile(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_related_profile(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_related_profile(uuid) TO authenticated;

-- ------------------------------------------------------------------------------
-- 3) PROFILES policies - explicitly scoped TO authenticated.
--    Anonymous is excluded from all of these, so anon SELECT returns [] cleanly.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS profiles_select_owner ON public.profiles;
CREATE POLICY profiles_select_owner
    ON public.profiles FOR SELECT TO authenticated
    USING (id = auth.uid());

DROP POLICY IF EXISTS profiles_select_related ON public.profiles;
CREATE POLICY profiles_select_related
    ON public.profiles FOR SELECT TO authenticated
    USING (public.is_related_profile(id));

DROP POLICY IF EXISTS profiles_insert_owner ON public.profiles;
CREATE POLICY profiles_insert_owner
    ON public.profiles FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS profiles_update_owner ON public.profiles;
CREATE POLICY profiles_update_owner
    ON public.profiles FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- ------------------------------------------------------------------------------
-- 4) NOTIFICATIONS policies - explicitly scoped TO authenticated.
--    Anonymous is excluded from all of these, so anon SELECT returns [] cleanly.
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS notifications_select_owner ON public.notifications;
CREATE POLICY notifications_select_owner
    ON public.notifications FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_insert_owner ON public.notifications;
CREATE POLICY notifications_insert_owner
    ON public.notifications FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS notifications_update_owner ON public.notifications;
CREATE POLICY notifications_update_owner
    ON public.notifications FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- No DELETE policies created anywhere: the system is append-only and no client
-- flow deletes profiles or notifications. Absence of a DELETE policy (with RLS
-- enabled) revokes delete access for both anon and authenticated, as intended.
-- No financial tables, RPCs, balances, KSP, or store/daily-profit logic touched.
-- ==============================================================================
