-- ==============================================================================
-- KASBY P0-1 ROOT-CAUSE CORRECTION : re-scope pre-existing {public} policies
-- ==============================================================================
-- Root cause (confirmed by live pg_policies + role_table_grants catalog):
--   Profiles/notifications RLS is ENABLED (relrowsecurity=true) and anon has
--   SELECT grants; anon is a member of PUBLIC. Pre-existing {public}-scoped
--   policies still apply to anon and are the anonymous data leak:
--     * profiles      : "Anyone can view active agents profiles"
--                       (qual includes EXISTS(... active agent) -> anon reads
--                        every active-agent profile row, all columns/PII)
--     * notifications : "User view notifs"
--                       (qual includes target = 'all' -> anon reads every
--                        broadcast notification)
--   Prior migrations (20260828000000 / ...00100) only dropped/created OUR OWN
--   differently-named policies and never removed these pre-existing {public}
--   leaks. Migration 1 made anon hit 42501 (our no-TO policy called
--   is_related_profile with EXECUTE revoked); migration 2 scoped our policies
--   TO authenticated (removing that error) but left the {public} leaks intact,
--   so anon read access returned cleanly -> the observed "regression".
--
-- This migration re-scopes those specific pre-existing policies to
-- TO authenticated, preserving IDENTICAL quals (identical authenticated
-- behavior) and removing anonymous from their evaluation. anon SELECT on both
-- tables then returns [].
--
-- It ONLY touches the named policies on public.profiles and
-- public.notifications. It does NOT modify/create/drop any financial table,
-- RPC, balance, KSP, store, daily-profit, FCM, Realtime, or notification
-- business logic, and does NOT UPDATE/INSERT/DELETE/TRUNCATE any data.
--
-- IDEMPOTENT / REVERSIBLE / NO DATA LOSS. Safe to re-run.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- PROFILES : re-scope pre-existing {public} policies to authenticated
-- ==============================================================================

DROP POLICY IF EXISTS "Anyone can view active agents profiles" ON public.profiles;
CREATE POLICY "Anyone can view active agents profiles"
    ON public.profiles FOR SELECT TO authenticated
    USING (
        (EXISTS (SELECT 1 FROM public.agents
                 WHERE agents.user_id = profiles.id
                   AND agents.status = 'active'::text))
        OR (auth.uid() = id)
        OR is_admin()
    );

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT TO authenticated
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE TO authenticated
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Agents can view assigned user profiles" ON public.profiles;
CREATE POLICY "Agents can view assigned user profiles"
    ON public.profiles FOR SELECT TO authenticated
    USING (is_agent() AND (id IN (
        SELECT transactions.user_id
        FROM public.transactions
        WHERE transactions.reference_id = (auth.uid())::text
    )));

DROP POLICY IF EXISTS "Admins can read all profiles" ON public.profiles;
CREATE POLICY "Admins can read all profiles"
    ON public.profiles FOR SELECT TO authenticated
    USING (is_admin());

-- ==============================================================================
-- NOTIFICATIONS : re-scope pre-existing {public} policies to authenticated
-- ==============================================================================

DROP POLICY IF EXISTS "User view notifs" ON public.notifications;
CREATE POLICY "User view notifs"
    ON public.notifications FOR SELECT TO authenticated
    USING ((user_id = auth.uid()) OR (target = 'all'::text));

DROP POLICY IF EXISTS "User update own notifs" ON public.notifications;
CREATE POLICY "User update own notifs"
    ON public.notifications FOR UPDATE TO authenticated
    USING ((user_id = auth.uid()))
    WITH CHECK ((user_id = auth.uid()));

DROP POLICY IF EXISTS "Admins have full access to notifications" ON public.notifications;
CREATE POLICY "Admins have full access to notifications"
    ON public.notifications FOR ALL TO authenticated
    USING (is_admin())
    WITH CHECK (is_admin());

-- ==============================================================================
-- NOTE: Our own TO-authenticated policies from the prior migrations
-- (profiles_select_owner/_related/_insert_owner/_update_owner and
--  notifications_select_owner/_insert_owner/_update_owner) are already correctly
-- scoped and are intentionally left untouched. No DELETE policies created
-- anywhere (append-only). No financial objects referenced.
-- ==============================================================================

COMMIT;
