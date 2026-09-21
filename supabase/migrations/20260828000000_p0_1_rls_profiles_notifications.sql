-- ==============================================================================
-- KASBY P0-1 : Close confirmed anonymous PII exposure on `profiles` & `notifications`
-- ==============================================================================
-- SCOPE (STRICTLY limited to P0-1, per remediation plan):
--   * ENABLE Row Level Security on public.profiles and public.notifications ONLY.
--   * Deny anonymous reads/writes on both tables (the confirmed live exposure:
--     anon could read 100% of profiles and 100% of notifications).
--   * Relationship-scoped access for AUTHENTICATED users so NO legitimate
--     application flow regresses:
--       - owner can read/update own profile  (id = auth.uid())
--       - owner can read/update own notifications (user_id = auth.uid())
--       - authenticated can read profile rows of related users only:
--           * team/member (referee) rows     (profiles.referred_by = auth.uid())
--           * friends                        (shared friendships row)
--           * active agents                  (agents.status = 'active')
--           * chat participants              (shared chat_conversations)
--   * NO financial tables, balances, KSP, transfers, withdrawals, deposits,
--     investments, store or subscription logic are touched.
--   * Append-only: NO DELETE policies are created (data is never deleted).
--
-- IDEMPOTENT: safe to re-run. ENABLE RLS is idempotent; all policies use
-- DROP POLICY IF EXISTS before CREATE POLICY.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1) RLS helper: is the target profile a legitimate relationship for the caller?
--    Used by the profiles SELECT policy so that authenticated relational reads
--    (team, friends, agents, chat) keep working while anonymous access is denied.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_related_profile(target_user uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller uuid := auth.uid();
BEGIN
    IF v_caller IS NULL THEN
        RETURN false;
    END IF;

    RETURN (
        -- 1) The caller's own profile
        target_user = v_caller
        -- 2) Team / member rows: profiles this caller referred
        OR EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = target_user
              AND p.referred_by = v_caller
        )
        -- 3) Friends: a shared friendships row
        OR EXISTS (
            SELECT 1 FROM public.friendships f
            WHERE (f.user_low_id = LEAST(v_caller, target_user)
                   AND f.user_high_id = GREATEST(v_caller, target_user))
        )
        -- 4) Active agents (agents directory)
        OR EXISTS (
            SELECT 1 FROM public.agents a
            WHERE a.user_id = target_user
              AND a.status = 'active'
        )
        -- 5) Chat/support/agent participants: caller and target share a conversation
        OR EXISTS (
            SELECT 1 FROM public.chat_conversations c
            WHERE (
                -- social P2P chat
                (c.user_low_id = LEAST(v_caller, target_user)
                 AND c.user_high_id = GREATEST(v_caller, target_user))
                -- support chat: caller is the user, target is the assigned admin
                OR (c.user_id = v_caller AND c.assigned_admin_id = target_user)
                -- support chat: caller is the assigned admin, target is the user
                OR (c.assigned_admin_id = v_caller AND c.user_id = target_user)
                -- agent chat: caller is the user, target is the agent's owning user id
                OR (c.user_id = v_caller
                    AND EXISTS (SELECT 1 FROM public.agents a2
                                WHERE a2.id = c.agent_id AND a2.user_id = target_user))
                -- agent chat: caller is the agent's owning user id, target is the user
                OR ((SELECT a3.user_id FROM public.agents a3 WHERE a3.id = c.agent_id) = v_caller
                    AND c.user_id = target_user)
            )
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.is_related_profile(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_related_profile(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.is_related_profile(uuid) TO authenticated;

-- ------------------------------------------------------------------------------
-- 2) PROFILES RLS
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- owner can read own profile (full)
DROP POLICY IF EXISTS profiles_select_owner ON public.profiles;
CREATE POLICY profiles_select_owner
    ON public.profiles FOR SELECT
    USING (id = auth.uid());

-- authenticated can read profile rows of people they are related to (team/friends/agents/chat)
DROP POLICY IF EXISTS profiles_select_related ON public.profiles;
CREATE POLICY profiles_select_related
    ON public.profiles FOR SELECT
    USING (public.is_related_profile(id));

-- self profile provisioning / edits
DROP POLICY IF EXISTS profiles_insert_owner ON public.profiles;
CREATE POLICY profiles_insert_owner
    ON public.profiles FOR INSERT
    WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS profiles_update_owner ON public.profiles;
CREATE POLICY profiles_update_owner
    ON public.profiles FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- ------------------------------------------------------------------------------
-- 3) NOTIFICATIONS RLS
-- ------------------------------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- owner can read own notifications
DROP POLICY IF EXISTS notifications_select_owner ON public.notifications;
CREATE POLICY notifications_select_owner
    ON public.notifications FOR SELECT
    USING (user_id = auth.uid());

-- owner can create own notifications (defensive for SECURITY INVOKER flows)
DROP POLICY IF EXISTS notifications_insert_owner ON public.notifications;
CREATE POLICY notifications_insert_owner
    ON public.notifications FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- owner can mark own notifications read
DROP POLICY IF EXISTS notifications_update_owner ON public.notifications;
CREATE POLICY notifications_update_owner
    ON public.notifications FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- No DELETE policies are created anywhere: the system is append-only and no
-- client flow deletes profiles or notifications. Absence of a DELETE policy
-- (combined with RLS being enabled) revokes delete access, as intended.
-- ==============================================================================
