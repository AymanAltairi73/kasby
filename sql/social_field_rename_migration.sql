-- ==============================================================================
-- KASBY SOCIAL FIELD RENAME MIGRATION — SAFE PRODUCTION MIGRATION
-- Date: 2026-04-19
-- Purpose: Rename ambiguous field names to clear, intent-revealing names.
--
-- CHANGES:
--   friend_requests: sender_id    → requester_id
--   friendships:     user_id      → user_low_id
--   friendships:     friend_id    → user_high_id
--   chat_conversations: (add)     user_low_id, user_high_id
--
-- SAFETY:
--   - Uses IF EXISTS guards
--   - Uses DO blocks to catch duplicate_column errors
--   - Drops and recreates constraints, RLS, RPCs idempotently
--   - Zero downtime, zero data loss
--
-- INSTRUCTIONS:
--   1. BACKUP YOUR DATABASE FIRST
--   2. Run in Supabase SQL Editor
--   3. Verify with: SELECT * FROM friend_requests LIMIT 1;
--                    SELECT * FROM friendships LIMIT 1;
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- ██╗  PHASE 1: RENAME COLUMNS (friend_requests)
-- ==============================================================================

-- 1.1 Rename sender_id → requester_id (if old column exists)
DO $$
BEGIN
    -- Check if old column exists and new column does NOT
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friend_requests' AND column_name = 'sender_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friend_requests' AND column_name = 'requester_id'
    ) THEN
        ALTER TABLE public.friend_requests RENAME COLUMN sender_id TO requester_id;
        RAISE NOTICE 'Renamed friend_requests.sender_id → requester_id';
    ELSE
        RAISE NOTICE 'friend_requests.requester_id already exists or sender_id not found — skipping rename';
    END IF;
END $$;

-- 1.2 Drop old constraint (if exists) and recreate with new name
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS unique_friend_request;
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS unique_pending_request;

-- Recreate UNIQUE constraint with correct column name
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_pending_request') THEN
        ALTER TABLE public.friend_requests 
            ADD CONSTRAINT unique_pending_request UNIQUE (requester_id, receiver_id);
    END IF;
END $$;

-- 1.3 Recreate no_self_request CHECK
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS no_self_request;
ALTER TABLE public.friend_requests 
    ADD CONSTRAINT no_self_request CHECK (requester_id != receiver_id);

-- 1.4 Comments
COMMENT ON TABLE public.friend_requests IS 'Stores friend requests between users.';
COMMENT ON COLUMN public.friend_requests.requester_id IS 'User who sent the request';
COMMENT ON COLUMN public.friend_requests.receiver_id IS 'User who received the request';

-- 1.5 Indexes
DROP INDEX IF EXISTS idx_fr_receiver;
DROP INDEX IF EXISTS idx_fr_sender;
CREATE INDEX IF NOT EXISTS idx_fr_receiver ON public.friend_requests(receiver_id, status);
CREATE INDEX IF NOT EXISTS idx_fr_requester ON public.friend_requests(requester_id, status);


-- ==============================================================================
-- ██████╗  PHASE 2: RENAME COLUMNS (friendships)
-- ==============================================================================

-- 2.1 Rename user_id → user_low_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friendships' AND column_name = 'user_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friendships' AND column_name = 'user_low_id'
    ) THEN
        ALTER TABLE public.friendships RENAME COLUMN user_id TO user_low_id;
        RAISE NOTICE 'Renamed friendships.user_id → user_low_id';
    ELSE
        RAISE NOTICE 'friendships.user_low_id already exists or user_id not found — skipping rename';
    END IF;
END $$;

-- 2.2 Rename friend_id → user_high_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friendships' AND column_name = 'friend_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friendships' AND column_name = 'user_high_id'
    ) THEN
        ALTER TABLE public.friendships RENAME COLUMN friend_id TO user_high_id;
        RAISE NOTICE 'Renamed friendships.friend_id → user_high_id';
    ELSE
        RAISE NOTICE 'friendships.user_high_id already exists or friend_id not found — skipping rename';
    END IF;
END $$;

-- 2.3 Drop old constraints and recreate
ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS unique_friendship;
ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS unique_friendship_pair;
ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS no_self_friend;
ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS check_user_order;

-- Strict ordering: user_low_id < user_high_id
ALTER TABLE public.friendships 
    ADD CONSTRAINT check_user_order CHECK (user_low_id < user_high_id);

-- Unique pair
ALTER TABLE public.friendships 
    ADD CONSTRAINT unique_friendship_pair UNIQUE (user_low_id, user_high_id);

-- 2.4 Comments
COMMENT ON TABLE public.friendships IS 'Stores established friendships with strict user ID ordering.';
COMMENT ON COLUMN public.friendships.user_low_id IS 'Always the smaller user id';
COMMENT ON COLUMN public.friendships.user_high_id IS 'Always the larger user id';

-- 2.5 Indexes
DROP INDEX IF EXISTS idx_friendships_user;
DROP INDEX IF EXISTS idx_friendships_friend;
CREATE INDEX IF NOT EXISTS idx_friendships_low ON public.friendships(user_low_id);
CREATE INDEX IF NOT EXISTS idx_friendships_high ON public.friendships(user_high_id);


-- ==============================================================================
-- ██████╗  PHASE 3: PROFILES — Add rate limiting column
-- ==============================================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS last_friend_request_at TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.last_friend_request_at IS 'Timestamp of the last friend request sent by the user for rate limiting.';


-- ==============================================================================
-- ██████╗  PHASE 4: CHAT CONVERSATIONS — Add P2P & category columns
-- ==============================================================================

-- Add category column FIRST (production schema doesn't have it)
ALTER TABLE public.chat_conversations
    ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'support';

COMMENT ON COLUMN public.chat_conversations.category IS 'Conversation type: support (user-to-admin) or social (P2P friend chat)';

-- Add P2P social chat columns
ALTER TABLE public.chat_conversations
    ADD COLUMN IF NOT EXISTS user_low_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS user_high_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Enforce ordering ONLY for social conversations (not support)
ALTER TABLE public.chat_conversations
    DROP CONSTRAINT IF EXISTS check_chat_user_order;

ALTER TABLE public.chat_conversations
    ADD CONSTRAINT check_chat_user_order CHECK (
        (category != 'social') OR
        (user_low_id IS NOT NULL AND user_high_id IS NOT NULL AND user_low_id < user_high_id)
    );

COMMENT ON COLUMN public.chat_conversations.user_low_id IS 'Always the smaller user id (used for P2P social chats)';
COMMENT ON COLUMN public.chat_conversations.user_high_id IS 'Always the larger user id (used for P2P social chats)';


-- ==============================================================================
-- ██╗  ██╗  PHASE 4: RLS POLICIES (Updated)
-- ==============================================================================

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- 4.1 Friend Requests
DROP POLICY IF EXISTS "Users view own requests" ON public.friend_requests;
CREATE POLICY "Users view own requests" ON public.friend_requests FOR SELECT
    USING (auth.uid() = requester_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users insert requests" ON public.friend_requests;
CREATE POLICY "Users insert requests" ON public.friend_requests FOR INSERT
    WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "Admin full access requests" ON public.friend_requests;
CREATE POLICY "Admin full access requests" ON public.friend_requests FOR ALL 
    USING (public.is_admin());

-- 4.2 Friendships
DROP POLICY IF EXISTS "Users view own friendships" ON public.friendships;
CREATE POLICY "Users view own friendships" ON public.friendships FOR SELECT
    USING (auth.uid() = user_low_id OR auth.uid() = user_high_id);

DROP POLICY IF EXISTS "Admin full access friendships" ON public.friendships;
CREATE POLICY "Admin full access friendships" ON public.friendships FOR ALL 
    USING (public.is_admin());


-- ==============================================================================
-- ███████╗  PHASE 5: RECREATE ALL SOCIAL RPCs
-- ==============================================================================

-- 5.1 Send Friend Request (Hardened)
CREATE OR REPLACE FUNCTION public.send_friend_request(p_receiver_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_requester_id UUID := auth.uid();
    v_last_request TIMESTAMPTZ;
BEGIN
    IF v_requester_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    IF v_requester_id = p_receiver_id THEN
        RETURN json_build_object('success', FALSE, 'error', 'cannot_add_self');
    END IF;

    -- 1. Rate Limiting Check (60 seconds)
    SELECT last_friend_request_at INTO v_last_request FROM profiles WHERE id = v_requester_id;
    IF v_last_request IS NOT NULL AND (NOW() - v_last_request) < INTERVAL '60 seconds' THEN
        RETURN json_build_object('success', FALSE, 'error', 'rate_limit_exceeded');
    END IF;

    -- 2. Check if already friends (using standardized user_low_id/user_high_id)
    IF EXISTS (
        SELECT 1 FROM friendships
        WHERE user_low_id = LEAST(v_requester_id, p_receiver_id)
          AND user_high_id = GREATEST(v_requester_id, p_receiver_id)
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'already_friends');
    END IF;

    -- 3. Check if request already exists
    IF EXISTS (
        SELECT 1 FROM friend_requests
        WHERE requester_id = v_requester_id AND receiver_id = p_receiver_id AND status = 'pending'
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_already_pending');
    END IF;

    -- 4. Check for reverse request (Auto-Accept)
    IF EXISTS (
        SELECT 1 FROM friend_requests
        WHERE requester_id = p_receiver_id AND receiver_id = v_requester_id AND status = 'pending'
    ) THEN
        UPDATE friend_requests SET status = 'accepted'
        WHERE requester_id = p_receiver_id AND receiver_id = v_requester_id;

        INSERT INTO friendships (user_low_id, user_high_id)
        VALUES (LEAST(v_requester_id, p_receiver_id), GREATEST(v_requester_id, p_receiver_id))
        ON CONFLICT DO NOTHING;

        RETURN json_build_object('success', TRUE, 'auto_accepted', TRUE);
    END IF;

    -- 5. Insert Request & Update Rate Limit
    INSERT INTO friend_requests (requester_id, receiver_id)
    VALUES (v_requester_id, p_receiver_id);

    UPDATE profiles SET last_friend_request_at = NOW() WHERE id = v_requester_id;

    RETURN json_build_object('success', TRUE);
END;
$$;


-- 5.2 Accept Friend Request
CREATE OR REPLACE FUNCTION public.accept_friend_request(p_request_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_requester_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    SELECT requester_id INTO v_requester_id
    FROM friend_requests
    WHERE id = p_request_id AND receiver_id = v_user_id AND status = 'pending';

    IF v_requester_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_not_found');
    END IF;

    UPDATE friend_requests SET status = 'accepted' WHERE id = p_request_id;

    INSERT INTO friendships (user_low_id, user_high_id)
    VALUES (LEAST(v_user_id, v_requester_id), GREATEST(v_user_id, v_requester_id))
    ON CONFLICT DO NOTHING;

    RETURN json_build_object('success', TRUE);
END;
$$;


-- 5.3 Reject Friend Request
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
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    UPDATE friend_requests SET status = 'rejected'
    WHERE id = p_request_id AND receiver_id = v_user_id AND status = 'pending';

    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_not_found');
    END IF;

    RETURN json_build_object('success', TRUE);
END;
$$;


-- 5.4 Get Friend Requests (incoming pending) — uses requester_id
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
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
    FROM (
        SELECT fr.id AS request_id, fr.requester_id, fr.created_at,
               p.full_name, p.avatar_url, p.referral_code
        FROM friend_requests fr
        JOIN profiles p ON p.id = fr.requester_id
        WHERE fr.receiver_id = v_user_id AND fr.status = 'pending'
        ORDER BY fr.created_at DESC
    ) r;

    RETURN json_build_object('success', TRUE, 'requests', v_result);
END;
$$;


-- 5.5 Get Friends List — uses user_low_id/user_high_id
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
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
    FROM (
        SELECT p.id, p.full_name, p.avatar_url, p.referral_code, f.created_at AS friends_since
        FROM friendships f
        JOIN profiles p ON p.id = CASE 
            WHEN f.user_low_id = v_user_id THEN f.user_high_id 
            ELSE f.user_low_id 
        END
        WHERE f.user_low_id = v_user_id OR f.user_high_id = v_user_id
        ORDER BY f.created_at DESC
    ) r;

    RETURN json_build_object('success', TRUE, 'friends', v_result);
END;
$$;


-- 5.6 Get Friend Suggestions — uses user_low_id/user_high_id
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
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
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
              WHERE (user_low_id = LEAST(v_user_id, p.id) AND user_high_id = GREATEST(v_user_id, p.id))
          )
          AND NOT EXISTS (
              SELECT 1 FROM friend_requests
              WHERE (requester_id = v_user_id AND receiver_id = p.id AND status = 'pending')
                 OR (requester_id = p.id AND receiver_id = v_user_id AND status = 'pending')
          )
        ORDER BY RANDOM()
        LIMIT 20
    ) r;

    RETURN json_build_object('success', TRUE, 'suggestions', v_result);
END;
$$;


-- 5.7 Cancel Friend Request — uses requester_id
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
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    DELETE FROM friend_requests
    WHERE requester_id = v_user_id AND receiver_id = p_receiver_id AND status = 'pending';

    IF NOT FOUND THEN
        RETURN json_build_object('success', FALSE, 'error', 'request_not_found');
    END IF;

    RETURN json_build_object('success', TRUE);
END;
$$;


-- 5.8 Remove Friend — uses user_low_id/user_high_id
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
        RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
    END IF;

    -- Delete friendship (strict ordering makes this simple)
    DELETE FROM friendships
    WHERE user_low_id = LEAST(v_user_id, p_friend_id)
      AND user_high_id = GREATEST(v_user_id, p_friend_id);

    -- Also delete associated friend requests (cleanup)
    DELETE FROM friend_requests
    WHERE (requester_id = v_user_id AND receiver_id = p_friend_id)
       OR (requester_id = p_friend_id AND receiver_id = v_user_id);

    RETURN json_build_object('success', TRUE);
END;
$$;


-- 5.9 Start Social Chat — uses user_low_id/user_high_id
CREATE OR REPLACE FUNCTION public.start_social_chat(p_friend_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_low_id UUID := LEAST(v_user_id, p_friend_id);
    v_high_id UUID := GREATEST(v_user_id, p_friend_id);
    v_conv_id UUID;
BEGIN
    -- Verify friendship exists
    IF NOT EXISTS (
        SELECT 1 FROM friendships
        WHERE user_low_id = v_low_id AND user_high_id = v_high_id
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'must_be_friends_to_chat');
    END IF;

    -- Get existing or create new
    SELECT id INTO v_conv_id FROM chat_conversations
    WHERE user_low_id = v_low_id AND user_high_id = v_high_id AND category = 'social';

    IF v_conv_id IS NULL THEN
        INSERT INTO chat_conversations (user_id, user_low_id, user_high_id, category)
        VALUES (v_user_id, v_low_id, v_high_id, 'social')
        RETURNING id INTO v_conv_id;
    END IF;

    RETURN json_build_object('success', TRUE, 'conversation_id', v_conv_id);
END;
$$;


-- ==============================================================================
-- ██████╗  PHASE 6: NOTIFICATION TRIGGERS (Updated)
-- ==============================================================================

-- 6.0 Update notifications constraints to allow social targets and types
-- Production constraints only allow a limited set of values
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_target_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_target_check
    CHECK (target = ANY (ARRAY['all', 'specific', 'social', 'chat']));

-- Expand type check to include social types and 'notification'
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IN (
        -- Financial
        'deposit_submitted', 'deposit_approved', 'deposit_rejected',
        'withdrawal_requested', 'withdrawal_approved', 'withdrawal_rejected', 'withdrawal_completed',
        'transfer_received', 'transfer_sent',
        -- Loans
        'loan_requested', 'loan_approved', 'loan_rejected',
        'loan_repayment_due', 'loan_overdue', 'loan_paid',
        -- Investments
        'investment_created', 'daily_profit', 'investment_matured', 'investment_cancelled',
        -- Chat
        'chat_new_message', 'chat_admin_reply', 'chat_resolved', 'chat_escalated',
        -- Account
        'kyc_approved', 'kyc_rejected', 'account_flagged', 'account_frozen',
        'role_upgraded', 'referral_bonus',
        -- Agent
        'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change',
        -- Admin
        'admin_kyc_pending', 'admin_withdrawal_pending', 'admin_deposit_pending',
        'admin_flagged_user', 'admin_new_chat',
        -- Social
        'social_friend_request', 'social_friend_accepted', 'social_chat',
        -- System
        'system', 'maintenance', 'announcement', 'security_alert',
        -- Generic
        'info', 'warning', 'reward', 'notification'
    ));

-- 6.1 Friend Request Notifications — uses requester_id/receiver_id
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS trigger AS $$
DECLARE
    v_sender_name TEXT;
BEGIN
    SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.requester_id;

    IF TG_OP = 'INSERT' THEN
        -- New Request notification
        INSERT INTO notifications (user_id, title, message, target, target_user_id, type)
        VALUES (
            NEW.receiver_id,
            'طلب صداقة جديد',
            'أرسل لك ' || v_sender_name || ' طلب صداقة.',
            'social',
            NEW.requester_id,
            'social_friend_request'
        );
    ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
        -- Request Accepted notification
        SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.receiver_id;
        INSERT INTO notifications (user_id, title, message, target, target_user_id, type)
        VALUES (
            NEW.requester_id,
            'تم قبول طلب الصداقة',
            'وافق ' || v_sender_name || ' على طلب صداقتك.',
            'social',
            NEW.receiver_id,
            'social_friend_accepted'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_friend_request_notify ON public.friend_requests;
CREATE TRIGGER tr_friend_request_notify
    AFTER INSERT OR UPDATE ON public.friend_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_friend_request_notification();


-- ==============================================================================
-- GRANTS
-- ==============================================================================

GRANT EXECUTE ON FUNCTION public.send_friend_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_friend_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_friend_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_friend_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_friends() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_friend_suggestions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_friend_request(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_friend(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_social_chat(UUID) TO authenticated;

COMMIT;

-- ==============================================================================
-- END OF SOCIAL FIELD RENAME MIGRATION
-- ==============================================================================
