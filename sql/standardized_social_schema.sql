-- ============================================================
-- 🚀 STANDARDIZED SOCIAL & CHAT SYSTEM — PRODUCTION SCHEMA
-- ============================================================

-- 1. PROFILES ENHANCEMENT (Rate Limiting)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS last_friend_request_at TIMESTAMPTZ;

COMMENT ON COLUMN public.profiles.last_friend_request_at IS 'Timestamp of the last friend request sent by the user for rate limiting.';

-- 2. TABLES
-- ============================================================

-- Friend Requests
CREATE TABLE IF NOT EXISTS public.friend_requests (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, -- User who sent the request
    receiver_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, -- User who received the request
    status          TEXT NOT NULL DEFAULT 'pending', -- pending, accepted, rejected
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_pending_request UNIQUE (requester_id, receiver_id),
    CONSTRAINT no_self_request CHECK (requester_id != receiver_id)
);

COMMENT ON TABLE public.friend_requests IS 'Stores friend requests between users.';
COMMENT ON COLUMN public.friend_requests.requester_id IS 'User who sent the request';
COMMENT ON COLUMN public.friend_requests.receiver_id IS 'User who received the request';

-- Friendships (Strict Ordering enforced: user_low_id < user_high_id)
CREATE TABLE IF NOT EXISTS public.friendships (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_low_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, -- Always the smaller user id
    user_high_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE, -- Always the larger user id
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT check_user_order CHECK (user_low_id < user_high_id),
    CONSTRAINT unique_friendship_pair UNIQUE (user_low_id, user_high_id)
);

COMMENT ON TABLE public.friendships IS 'Stores established friendships with strict user ID ordering.';
COMMENT ON COLUMN public.friendships.user_low_id IS 'Always the smaller user id';
COMMENT ON COLUMN public.friendships.user_high_id IS 'Always the larger user id';

-- Chat Conversations (Adding P2P fields to consolidated schema)
-- We add these to the existing public.chat_conversations

-- Add category column FIRST (production schema doesn't have it)
ALTER TABLE public.chat_conversations
    ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'support';

COMMENT ON COLUMN public.chat_conversations.category IS 'Conversation type: support (user-to-admin) or social (P2P friend chat)';

ALTER TABLE public.chat_conversations 
ADD COLUMN IF NOT EXISTS user_low_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS user_high_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;

-- If we want to strictly enforce P2P ordering in the existing table
-- Ensure we don't break existing 'support' conversations where these might be null
ALTER TABLE public.chat_conversations
DROP CONSTRAINT IF EXISTS check_chat_user_order,
ADD CONSTRAINT check_chat_user_order CHECK (
    (category != 'social') OR -- Only enforce for social/direct chat
    (user_low_id IS NOT NULL AND user_high_id IS NOT NULL AND user_low_id < user_high_id)
);

COMMENT ON COLUMN public.chat_conversations.user_low_id IS 'Always the smaller user id';
COMMENT ON COLUMN public.chat_conversations.user_high_id IS 'Always the larger user id';

-- Chat Messages (Backward-compatible: add message_content, keep content)
-- Use ADD COLUMN instead of RENAME to avoid breaking old clients
-- Chat Messages (Backward-compatible: add message_content, keep content)
-- Use ADD COLUMN instead of RENAME to avoid breaking old clients
ALTER TABLE public.chat_messages 
ADD COLUMN IF NOT EXISTS message_content TEXT;

-- Backfill existing data safely
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'chat_messages' AND column_name = 'content'
    ) THEN
        UPDATE public.chat_messages
        SET message_content = content
        WHERE message_content IS NULL AND content IS NOT NULL;
    END IF;
END $$;

COMMENT ON COLUMN public.chat_messages.message_content IS 'The actual message body text (replaces legacy content column)';

-- 3. SAFE COLUMN RENAMES (handles existing tables with old column names)
-- ============================================================

-- If old archive table exists with sender_id, rename to requester_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friend_requests' AND column_name = 'sender_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'friend_requests' AND column_name = 'requester_id'
    ) THEN
        ALTER TABLE public.friend_requests RENAME COLUMN sender_id TO requester_id;
        RAISE NOTICE 'Renamed friend_requests.sender_id → requester_id';
    END IF;
END $$;

-- If old archive table exists with user_id/friend_id, rename
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
        ALTER TABLE public.friendships RENAME COLUMN friend_id TO user_high_id;
        RAISE NOTICE 'Renamed friendships columns to user_low_id/user_high_id';
    END IF;
END $$;

-- Ensure constraints exist with correct names
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS unique_friend_request;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_pending_request') THEN
        ALTER TABLE public.friend_requests 
            ADD CONSTRAINT unique_pending_request UNIQUE (requester_id, receiver_id);
    END IF;
END $$;

ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS unique_friendship;
ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS no_self_friend;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'check_user_order') THEN
        ALTER TABLE public.friendships 
            ADD CONSTRAINT check_user_order CHECK (user_low_id < user_high_id);
    END IF;
END $$;
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'unique_friendship_pair') THEN
        ALTER TABLE public.friendships 
            ADD CONSTRAINT unique_friendship_pair UNIQUE (user_low_id, user_high_id);
    END IF;
END $$;

-- 4. RLS POLICIES
-- ============================================================

ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users view own requests" ON friend_requests;
CREATE POLICY "Users view own requests" ON friend_requests FOR SELECT
    USING (auth.uid() = requester_id OR auth.uid() = receiver_id);

DROP POLICY IF EXISTS "Users insert requests" ON friend_requests;
CREATE POLICY "Users insert requests" ON friend_requests FOR INSERT
    WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "Users view own friendships" ON friendships;
CREATE POLICY "Users view own friendships" ON friendships FOR SELECT
    USING (auth.uid() = user_low_id OR auth.uid() = user_high_id);

-- 4. RPCs — STANDARDIZED & HARDENED
-- ============================================================

-- 4.1 Send Friend Request (Hardened)
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

    -- 2. Check if already friends
    IF EXISTS (
        SELECT 1 FROM friendships
        WHERE (user_low_id = LEAST(v_requester_id, p_receiver_id) AND user_high_id = GREATEST(v_requester_id, p_receiver_id))
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

-- 4.2 Accept Friend Request
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

-- 4.3 Start Social Chat (P2P Duplicate Prevention)
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
    -- Verify friendship exists and is accepted
    IF NOT EXISTS (
        SELECT 1 FROM friendships
        WHERE user_low_id = v_low_id AND user_high_id = v_high_id
    ) THEN
        RETURN json_build_object('success', FALSE, 'error', 'must_be_friends_to_chat');
    END IF;

    -- Get existsing or create new
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

-- 5. NOTIFICATION TRIGGERS
-- ============================================================

-- Update notifications constraints to allow social targets and types
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_target_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_target_check
    CHECK (target = ANY (ARRAY['all', 'specific', 'social', 'chat']));

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

-- 5.1 Friend Request Notifications
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS trigger AS $$
DECLARE
    v_sender_name TEXT;
BEGIN
    SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.requester_id;

    IF TG_OP = 'INSERT' THEN
        -- New Request
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
        -- Request Accepted
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

-- 5.2 Chat Message Trigger (Notification + Friendship Check)
CREATE OR REPLACE FUNCTION public.handle_chat_message_logic()
RETURNS trigger AS $$
DECLARE
    v_conv_category TEXT;
    v_peer_id UUID;
    v_sender_name TEXT;
    v_recipient_id UUID;
BEGIN
    -- 1. Get Conversation Details
    SELECT category, user_low_id, user_high_id INTO v_conv_category, v_recipient_id, v_peer_id
    FROM chat_conversations WHERE id = NEW.conversation_id;

    -- Determine recipient for P2P
    IF v_conv_category = 'social' THEN
        IF NEW.sender_id = v_recipient_id THEN
            v_recipient_id := v_peer_id;
        END IF;
        
        -- 2. STRICT SECURITY: Verify Friendship
        IF NOT EXISTS (
            SELECT 1 FROM friendships
            WHERE (user_low_id = LEAST(NEW.sender_id, v_recipient_id) 
              AND user_high_id = GREATEST(NEW.sender_id, v_recipient_id))
        ) THEN
            RAISE EXCEPTION 'Messaging only allowed between friends';
        END IF;
    ELSE
        -- For non-social (support), original logic applies but we target the other party
        -- (This is simplified for social hardenings)
        RETURN NEW;
    END IF;

    -- 3. NOTIFICATION
    SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.sender_id;
    
    INSERT INTO notifications (user_id, title, message, target, target_user_id, type)
    VALUES (
        v_recipient_id,
        'رسالة جديدة من ' || v_sender_name,
        CASE WHEN NEW.message_type = 'image' THEN '📷 صورة' ELSE LEFT(NEW.message_content, 100) END,
        'chat',
        NEW.sender_id,
        'social_chat'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_chat_message_logic ON public.chat_messages;
CREATE TRIGGER tr_chat_message_logic
    BEFORE INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_chat_message_logic();
