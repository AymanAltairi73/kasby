-- ============================================================
-- Social Network + My Team — Full Database Integration
-- Run this in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. TABLES
-- ============================================================

-- Friend Requests
CREATE TABLE IF NOT EXISTS public.friend_requests (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status      TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, rejected
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_friend_request UNIQUE (sender_id, receiver_id),
    CONSTRAINT no_self_request CHECK (sender_id != receiver_id)
);

CREATE INDEX IF NOT EXISTS idx_fr_receiver ON friend_requests(receiver_id, status);
CREATE INDEX IF NOT EXISTS idx_fr_sender ON friend_requests(sender_id, status);

-- Friendships (bidirectional — always stored with user_id < friend_id)
CREATE TABLE IF NOT EXISTS public.friendships (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    friend_id   UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_friendship UNIQUE (user_id, friend_id),
    CONSTRAINT no_self_friend CHECK (user_id != friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id);

-- ============================================================
-- 2. RLS POLICIES
-- ============================================================

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Friend Requests: users can view requests they sent or received
DROP POLICY IF EXISTS "Users view own requests" ON friend_requests;
CREATE POLICY "Users view own requests" ON friend_requests FOR SELECT
    USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users insert requests" ON friend_requests;
CREATE POLICY "Users insert requests" ON friend_requests FOR INSERT
    WITH CHECK (auth.uid() = sender_id);

-- Friendships: users can view their own friendships
DROP POLICY IF EXISTS "Users view own friendships" ON friendships;
CREATE POLICY "Users view own friendships" ON friendships FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Admin full access
DROP POLICY IF EXISTS "Admin full access requests" ON friend_requests;
CREATE POLICY "Admin full access requests" ON friend_requests FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Admin full access friendships" ON friendships;
CREATE POLICY "Admin full access friendships" ON friendships FOR ALL USING (public.is_admin());

-- ============================================================
-- 3. RPCs — SOCIAL NETWORK
-- ============================================================

-- 3.1 Send Friend Request
CREATE OR REPLACE FUNCTION public.send_friend_request(p_receiver_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;
    IF v_user_id = p_receiver_id THEN
        RETURN json_build_object('success', FALSE, 'error', 'cannot_add_self');
    END IF;

    -- Check if already friends
    IF EXISTS (
        SELECT 1 FROM friendships
        WHERE (user_id = v_user_id AND friend_id = p_receiver_id)
           OR (user_id = p_receiver_id AND friend_id = v_user_id)
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'already_friends');
    END IF;

    -- Check if request already exists
    IF EXISTS (
        SELECT 1 FROM friend_requests
        WHERE sender_id = v_user_id AND receiver_id = p_receiver_id AND status = 'pending'
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_already_sent');
    END IF;

    -- Check if reverse request exists (auto-accept)
    IF EXISTS (
        SELECT 1 FROM friend_requests
        WHERE sender_id = p_receiver_id AND receiver_id = v_user_id AND status = 'pending'
    ) THEN
        UPDATE friend_requests SET status = 'accepted'
        WHERE sender_id = p_receiver_id AND receiver_id = v_user_id AND status = 'pending';

        INSERT INTO friendships (user_id, friend_id)
        VALUES (LEAST(v_user_id, p_receiver_id), GREATEST(v_user_id, p_receiver_id));

        RETURN json_build_object('success', TRUE, 'auto_accepted', TRUE);
    END IF;

    INSERT INTO friend_requests (sender_id, receiver_id)
    VALUES (v_user_id, p_receiver_id);

    RETURN json_build_object('success', TRUE);
END;
$$;

-- 3.2 Accept Friend Request
CREATE OR REPLACE FUNCTION public.accept_friend_request(p_request_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_sender_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT sender_id INTO v_sender_id
    FROM friend_requests
    WHERE id = p_request_id AND receiver_id = v_user_id AND status = 'pending';

    IF v_sender_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_not_found');
    END IF;

    UPDATE friend_requests SET status = 'accepted' WHERE id = p_request_id;

    INSERT INTO friendships (user_id, friend_id)
    VALUES (LEAST(v_user_id, v_sender_id), GREATEST(v_user_id, v_sender_id))
    ON CONFLICT DO NOTHING;

    RETURN json_build_object('success', TRUE);
END;
$$;

-- 3.3 Reject Friend Request
CREATE OR REPLACE FUNCTION public.reject_friend_request(p_request_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    UPDATE friend_requests SET status = 'rejected'
    WHERE id = p_request_id AND receiver_id = v_user_id AND status = 'pending';

    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_not_found');
    END IF;

    RETURN json_build_object('success', TRUE);
END;
$$;

-- 3.4 Get Friend Requests (incoming pending)
CREATE OR REPLACE FUNCTION public.get_friend_requests()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result json;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
    FROM (
        SELECT fr.id AS request_id, fr.sender_id, fr.created_at,
               p.full_name, p.avatar_url, p.referral_code
        FROM friend_requests fr
        JOIN profiles p ON p.id = fr.sender_id
        WHERE fr.receiver_id = v_user_id AND fr.status = 'pending'
        ORDER BY fr.created_at DESC
    ) r;

    RETURN json_build_object('success', TRUE, 'requests', v_result);
END;
$$;

-- 3.5 Get Friends List
CREATE OR REPLACE FUNCTION public.get_friends()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result json;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
    FROM (
        SELECT p.id, p.full_name, p.avatar_url, p.referral_code, f.created_at AS friends_since
        FROM friendships f
        JOIN profiles p ON p.id = CASE WHEN f.user_id = v_user_id THEN f.friend_id ELSE f.user_id END
        WHERE f.user_id = v_user_id OR f.friend_id = v_user_id
        ORDER BY f.created_at DESC
    ) r;

    RETURN json_build_object('success', TRUE, 'friends', v_result);
END;
$$;

-- 3.6 Get Friend Suggestions (users who are NOT friends and NOT pending)
CREATE OR REPLACE FUNCTION public.get_friend_suggestions()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_result json;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
    FROM (
        SELECT p.id, p.full_name, p.avatar_url, p.referral_code
        FROM profiles p
        WHERE p.id != v_user_id
          AND p.role = 'user'
          AND p.status = 'active'
          AND NOT EXISTS (
              SELECT 1 FROM friendships
              WHERE (user_id = v_user_id AND friend_id = p.id)
                 OR (user_id = p.id AND friend_id = v_user_id)
          )
          AND NOT EXISTS (
              SELECT 1 FROM friend_requests
              WHERE (sender_id = v_user_id AND receiver_id = p.id AND status = 'pending')
                 OR (sender_id = p.id AND receiver_id = v_user_id AND status = 'pending')
          )
        ORDER BY RANDOM()
        LIMIT 20
    ) r;

    RETURN json_build_object('success', TRUE, 'suggestions', v_result);
END;
$$;

-- ============================================================
-- 4. RPCs — MY TEAM (Referral Tree)
-- ============================================================

-- 4.1 Get My Team (direct referrals + stats)
CREATE OR REPLACE FUNCTION public.get_my_team()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_members json;
    v_total_count INTEGER;
    v_referral_code TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    -- Get user's referral code
    SELECT referral_code INTO v_referral_code FROM profiles WHERE id = v_user_id;

    -- Count total team members (Level 1 only for now)
    SELECT COUNT(*) INTO v_total_count
    FROM profiles WHERE referred_by_id = v_user_id;

    -- Get team members
    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_members
    FROM (
        SELECT p.id, p.full_name, p.avatar_url, p.created_at, p.status,
               (SELECT COUNT(*) FROM profiles WHERE referred_by_id = p.id) AS sub_referrals
        FROM profiles p
        WHERE p.referred_by_id = v_user_id
        ORDER BY p.created_at DESC
    ) r;

    RETURN json_build_object(
        'success', TRUE,
        'my_referral_code', v_referral_code,
        'total_members', v_total_count,
        'members', v_members
    );
END;
$$;

-- 3.7 Cancel Friend Request (retract a request sent by user)
CREATE OR REPLACE FUNCTION public.cancel_friend_request(p_receiver_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    DELETE FROM friend_requests
    WHERE sender_id = v_user_id AND receiver_id = p_receiver_id AND status = 'pending';

    IF NOT FOUND THEN
        -- If not found as sender, check if we are the receiver and it's pending (uncommon case for "cancel")
        -- but good for robustness
        RETURN json_build_object('success', FALSE, 'error', 'request_not_found');
    END IF;

    RETURN json_build_object('success', TRUE);
END;
$$;

-- 3.8 Remove Friend (unfriend)
CREATE OR REPLACE FUNCTION public.remove_friend(p_friend_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    -- Delete friendship (bidirectional)
    DELETE FROM friendships
    WHERE (user_id = v_user_id AND friend_id = p_friend_id)
       OR (user_id = p_friend_id AND friend_id = v_user_id);

    -- Also delete associated friend requests (to clean up schema)
    DELETE FROM friend_requests
    WHERE (sender_id = v_user_id AND receiver_id = p_friend_id)
       OR (sender_id = p_friend_id AND receiver_id = v_user_id);

    RETURN json_build_object('success', TRUE);
END;
$$;

