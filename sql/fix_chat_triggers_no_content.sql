-- ==============================================================================
-- KASBY — FIX CHAT TRIGGERS AFTER content COLUMN WAS DROPPED
-- ==============================================================================
-- Problem: record "new" has no field "content" (code 42703)
-- Cause: The old `content` column was dropped (chat_cleanup_old_content.sql)
--        but triggers still reference NEW.content as fallback.
-- Fix:   Update ALL triggers on chat_messages to use ONLY message_content.
-- ==============================================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. Chat Push Notification Trigger — remove content fallback
-- ═══════════════════════════════════════════════════════════════

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

    -- Use message_content ONLY (content column was dropped)
    v_msg_text := NEW.message_content;

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
DROP TRIGGER IF EXISTS trg_chat_push ON public.chat_messages;
CREATE TRIGGER trg_chat_push
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_trigger_chat_push_notification();


-- ═══════════════════════════════════════════════════════════════
-- 2. Social Chat Message Logic Trigger — remove content fallback
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_chat_message_logic()
RETURNS trigger AS $$
DECLARE
    v_conv_category TEXT;
    v_peer_id UUID;
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_msg_text TEXT;
BEGIN
    -- Use message_content ONLY (content column was dropped)
    v_msg_text := NEW.message_content;

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


-- ═══════════════════════════════════════════════════════════════
-- 3. Drop the sync trigger if it still exists (no longer needed)
-- ═══════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS trg_sync_chat_content ON public.chat_messages;
DROP FUNCTION IF EXISTS public.fn_sync_chat_message_content();
