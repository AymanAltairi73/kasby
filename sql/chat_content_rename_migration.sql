-- ==============================================================================
-- KASBY CHAT CONTENT RENAME MIGRATION — BACKWARD-COMPATIBLE
-- Date: 2026-04-19
-- Purpose: Add message_content column to chat_messages while keeping old content
--          column alive during transition. Zero downtime, zero data loss.
--
-- STRATEGY:
--   1. Add new column: message_content
--   2. Backfill existing data: content → message_content
--   3. Create sync trigger: writes to BOTH columns on INSERT/UPDATE
--   4. Update RPCs to write to message_content (+ trigger syncs to content)
--   5. Update notification trigger to read message_content
--   6. After all apps deployed → run cleanup SQL to drop old column
--
-- INSTRUCTIONS:
--   1. BACKUP YOUR DATABASE FIRST
--   2. Run this SQL in Supabase SQL Editor
--   3. Deploy Flutter app updates (models read message_content, fallback to content)
--   4. After all clients updated → run chat_cleanup_old_content.sql
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- ██╗  PHASE 1: ADD NEW COLUMN + BACKFILL
-- ==============================================================================

-- 1.1 Add message_content column (keeps old content column untouched)
ALTER TABLE public.chat_messages
    ADD COLUMN IF NOT EXISTS message_content TEXT;

-- 1.2 Backfill: copy existing content → message_content
UPDATE public.chat_messages
SET message_content = content
WHERE message_content IS NULL AND content IS NOT NULL;

-- 1.3 Comments
COMMENT ON COLUMN public.chat_messages.message_content IS 'The actual message body text (replaces legacy content column)';
COMMENT ON COLUMN public.chat_messages.content IS 'DEPRECATED — use message_content. Kept for backward compatibility during migration.';

-- 1.4 Set default for new inserts — if only content is provided, sync to message_content
--     and vice versa. We handle this with a trigger (Phase 2).


-- ==============================================================================
-- ██████╗  PHASE 2: SYNC TRIGGER (keeps both columns in sync)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.fn_sync_chat_message_content()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- On INSERT: if one is set and the other is not, sync them
    IF TG_OP = 'INSERT' THEN
        IF NEW.message_content IS NOT NULL AND NEW.content IS NULL THEN
            NEW.content := NEW.message_content;
        ELSIF NEW.content IS NOT NULL AND NEW.message_content IS NULL THEN
            NEW.message_content := NEW.content;
        END IF;
    END IF;

    -- On UPDATE: if message_content changed, sync to content
    IF TG_OP = 'UPDATE' THEN
        IF NEW.message_content IS DISTINCT FROM OLD.message_content THEN
            NEW.content := NEW.message_content;
        ELSIF NEW.content IS DISTINCT FROM OLD.content THEN
            NEW.message_content := NEW.content;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_chat_content ON public.chat_messages;
CREATE TRIGGER trg_sync_chat_content
    BEFORE INSERT OR UPDATE ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_chat_message_content();


-- ==============================================================================
-- ██████╗  PHASE 3: UPDATE RPCs — Use message_content
-- ==============================================================================

-- 3.1 Updated fn_send_chat_message — p_content renamed to p_message_content
-- MUST drop old signature first — PostgreSQL cannot rename params via CREATE OR REPLACE
DROP FUNCTION IF EXISTS public.fn_send_chat_message(UUID, TEXT, TEXT, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.fn_send_chat_message(
    p_conversation_id UUID,
    p_message_content TEXT,
    p_message_type TEXT DEFAULT 'text',
    p_reply_to_id UUID DEFAULT NULL,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_conv RECORD;
    v_sender_type TEXT;
    v_msg_id UUID;
    v_display_text TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF TRIM(p_message_content) = '' THEN
        RAISE EXCEPTION 'Message content cannot be empty';
    END IF;

    -- Lock conversation to prevent race conditions
    SELECT * INTO v_conv
    FROM public.chat_conversations
    WHERE id = p_conversation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conversation not found';
    END IF;

    -- Determine sender type based on role
    IF public.is_admin() THEN
        v_sender_type := 'admin';
    ELSIF v_conv.user_id = v_user_id THEN
        v_sender_type := 'user';
    ELSIF v_conv.is_agent_chat AND v_conv.agent_id = v_user_id THEN
        v_sender_type := 'agent';
    ELSE
        RAISE EXCEPTION 'You are not authorized to send messages in this conversation';
    END IF;

    -- Auto-reopen closed/resolved conversations when user/agent sends a message
    IF v_conv.status IN ('resolved', 'auto_closed') AND v_sender_type IN ('user', 'agent') THEN
        UPDATE public.chat_conversations
        SET status = 'reopened',
            is_closed = FALSE,
            resolved_at = NULL,
            resolved_by = NULL
        WHERE id = p_conversation_id;
    END IF;

    -- Build display text for last_message
    v_display_text := CASE
        WHEN p_message_type = 'image' THEN '📷 صورة'
        WHEN p_message_type = 'file'  THEN '📎 ملف'
        WHEN p_message_type = 'voice' THEN '🎤 رسالة صوتية'
        ELSE LEFT(p_message_content, 100)
    END;

    -- Insert message (trigger will sync content ↔ message_content)
    INSERT INTO public.chat_messages (
        conversation_id, sender_id, sender_type, message_content,
        message_type, reply_to_id, idempotency_key
    ) VALUES (
        p_conversation_id, v_user_id, v_sender_type,
        p_message_content, p_message_type, p_reply_to_id, p_idempotency_key
    )
    RETURNING id INTO v_msg_id;

    -- Auto-transition conversation status + update counters
    IF v_sender_type = 'admin' THEN
        UPDATE public.chat_conversations SET
            status = 'replied',
            last_message = v_display_text,
            last_message_at = NOW(),
            last_admin_reply_at = NOW(),
            unread_user_count = COALESCE(unread_user_count, 0) + 1
        WHERE id = p_conversation_id;
    ELSE
        UPDATE public.chat_conversations SET
            status = CASE
                WHEN v_conv.status IN ('replied', 'resolved', 'auto_closed', 'reopened', 'open')
                THEN 'waiting_admin'
                ELSE v_conv.status
            END,
            last_message = v_display_text,
            last_message_at = NOW(),
            last_user_message_at = NOW(),
            unread_admin_count = COALESCE(unread_admin_count, 0) + 1
        WHERE id = p_conversation_id;
    END IF;

    RETURN v_msg_id;
END;
$$;

-- Update grants for new signature
GRANT EXECUTE ON FUNCTION public.fn_send_chat_message(UUID, TEXT, TEXT, UUID, TEXT) TO authenticated;


-- ==============================================================================
-- ██╗  ██╗  PHASE 4: UPDATE NOTIFICATION TRIGGER — Use message_content
-- ==============================================================================

-- Update notifications constraints to allow social targets and types
-- (Safe to repeat these)
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

-- 4.1 Chat push notification trigger — reads message_content (with fallback to content)
CREATE OR REPLACE FUNCTION public.fn_trigger_chat_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_target_user_id UUID;
    v_sender_name TEXT;
    v_type TEXT;
    v_deep_link TEXT;
    v_msg_text TEXT;
BEGIN
    -- Skip system messages for push
    IF NEW.sender_type = 'system' THEN RETURN NEW; END IF;

    -- Use message_content with fallback to content for backward compatibility
    v_msg_text := COALESCE(NEW.message_content, NEW.content);

    -- Get sender name
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;
    IF v_sender_name IS NULL THEN v_sender_name := 'كاسبي'; END IF;

    IF NEW.sender_type = 'admin' THEN
        -- Admin sent → notify user
        SELECT user_id INTO v_target_user_id
        FROM public.chat_conversations WHERE id = NEW.conversation_id;
        v_type := 'chat_admin_reply';
        v_deep_link := '/support-chat';
    ELSIF NEW.sender_type IN ('user', 'agent') THEN
        -- User/Agent sent → notify assigned admin (or all admins)
        SELECT assigned_admin_id INTO v_target_user_id
        FROM public.chat_conversations WHERE id = NEW.conversation_id;

        -- If no assigned admin, notify all admins
        IF v_target_user_id IS NULL THEN
            DECLARE
                v_admin_ids UUID[];
            BEGIN
                SELECT ARRAY_AGG(id) INTO v_admin_ids
                FROM public.admin_profiles WHERE is_active = TRUE;

                IF v_admin_ids IS NOT NULL THEN
                    PERFORM public.fn_create_bulk_notification(
                        v_admin_ids,
                        'رسالة دعم جديدة من ' || v_sender_name,
                        CASE WHEN NEW.message_type = 'image' THEN '📷 صورة'
                             ELSE LEFT(v_msg_text, 80) END,
                        'admin_new_chat', 'conversation', NEW.conversation_id::TEXT,
                        '/chat', 'admin'
                    );
                END IF;
                RETURN NEW;
            END;
        END IF;

        v_type := 'chat_new_message';
        v_deep_link := '/chat';
    ELSE
        RETURN NEW;
    END IF;

    IF v_target_user_id IS NOT NULL THEN
        PERFORM public.fn_create_notification(
            v_target_user_id,
            'رسالة جديدة من ' || v_sender_name,
            CASE WHEN NEW.message_type = 'image' THEN '📷 صورة'
                 ELSE LEFT(v_msg_text, 80) END,
            v_type, 'conversation', NEW.conversation_id::TEXT, v_deep_link
        );
    END IF;

    RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS on_chat_message_inserted ON public.chat_messages;
DROP TRIGGER IF EXISTS trg_chat_push ON public.chat_messages;
CREATE TRIGGER trg_chat_push
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_trigger_chat_push_notification();


-- ==============================================================================
-- ███████╗  PHASE 5: UPDATE SOCIAL CHAT MESSAGE TRIGGER
-- ==============================================================================

-- Handle social chat message logic — uses message_content with fallback
CREATE OR REPLACE FUNCTION public.handle_chat_message_logic()
RETURNS trigger AS $$
DECLARE
    v_conv_category TEXT;
    v_peer_id UUID;
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_msg_text TEXT;
BEGIN
    -- Use message_content with fallback to content
    v_msg_text := COALESCE(NEW.message_content, NEW.content);

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
        -- For non-social (support), original logic applies
        RETURN NEW;
    END IF;

    -- 3. NOTIFICATION
    SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.sender_id;

    INSERT INTO notifications (user_id, title, message, target, target_user_id, type)
    VALUES (
        v_recipient_id,
        'رسالة جديدة من ' || v_sender_name,
        CASE WHEN NEW.message_type = 'image' THEN '📷 صورة' ELSE LEFT(v_msg_text, 100) END,
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


-- ==============================================================================
-- ██████╗  PHASE 6: UPDATE RLS (content references)
-- ==============================================================================

-- The existing RLS policies reference sender_id and conversation_id, NOT content.
-- So no RLS changes needed for the content → message_content rename.
-- Just ensure the insert policy allows message_content:
DROP POLICY IF EXISTS "Users insert own messages" ON public.chat_messages;
CREATE POLICY "Users insert own messages"
    ON public.chat_messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND sender_type IN ('user', 'agent')
        AND conversation_id IN (
            SELECT id FROM public.chat_conversations WHERE user_id = auth.uid()
        )
    );


COMMIT;

-- ==============================================================================
-- END OF CHAT CONTENT RENAME MIGRATION (BACKWARD-COMPATIBLE)
-- ==============================================================================

