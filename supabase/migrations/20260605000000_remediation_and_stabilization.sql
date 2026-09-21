-- ════════════════════════════════════════════════════════════════
-- KASBY PLATFORM REMEDIATION & STABILIZATION MIGRATION
-- Date: 2026-06-05
-- Description:
--   1. Secure internal API secret keys (private schema + keys table)
--   2. Notification Storm Elimination (deduplication of triggers and FCM post removal)
--   3. Dead/Orphaned Code & Unsafe Casting Function Cleanup
--   4. Social Chat RLS Policy Remediation
--   5. Social Chat Admin Notification Leak Fix
--   6. Atomic Chat Unread Counters & Last Message Trigger
--   7. Automated message read receipt trigger on chat_conversations update
--   8. fn_mark_messages_read social chat support
-- ════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────
-- PART 1: SECURE INTERNAL SECRETS SCHEMA
-- ────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE IF NOT EXISTS private.keys (
    key_name TEXT PRIMARY KEY,
    key_value TEXT NOT NULL
);

-- Revoke all access from public, anon, and authenticated roles to ensure strict security
REVOKE ALL ON SCHEMA private FROM public, anon, authenticated;
REVOKE ALL ON TABLE private.keys FROM public, anon, authenticated;

-- Insert secure default FCM secret
INSERT INTO private.keys (key_name, key_value)
VALUES ('fcm_secret', 'YOUR_INTERNAL_FCM_SECRET')
ON CONFLICT (key_name) DO UPDATE SET key_value = EXCLUDED.key_value;

-- Create security definer wrapper to fetch keys
CREATE OR REPLACE FUNCTION private.get_key(p_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN (SELECT key_value FROM private.keys WHERE key_name = p_name);
END;
$$;

-- ────────────────────────────────────────────────────────────────
-- PART 2: NOTIFICATION STORM ELIMINATION & TRIGGERS DEDUPLICATION
-- ────────────────────────────────────────────────────────────────

-- Drop redundant transaction notification triggers
DROP TRIGGER IF EXISTS "on_reward_transaction_inserted" ON "public"."transactions";
DROP TRIGGER IF EXISTS "trigger_transaction_notification" ON "public"."transactions";

-- Redefine fn_create_notification to insert a record only and avoid direct HTTP call
CREATE OR REPLACE FUNCTION "public"."fn_create_notification"(
    "p_user_id" "uuid", 
    "p_title" "text", 
    "p_body" "text", 
    "p_type" "text" DEFAULT 'system'::"text", 
    "p_entity_type" "text" DEFAULT NULL::"text", 
    "p_entity_id" "text" DEFAULT NULL::"text", 
    "p_deep_link" "text" DEFAULT NULL::"text", 
    "p_role_target" "text" DEFAULT 'user'::"text", 
    "p_priority" "text" DEFAULT 'normal'::"text"
) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_notif_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id, title, message, type, entity_type, entity_id,
        deep_link, role_target, priority, status
    ) VALUES (
        p_user_id, p_title, p_body, p_type, p_entity_type, p_entity_id,
        p_deep_link, p_role_target, p_priority, 'sent'
    )
    RETURNING id INTO v_notif_id;

    RETURN v_notif_id;
END;
$$;

-- Redefine trigger_generic_notification to use the secure private FCM secret key
CREATE OR REPLACE FUNCTION "public"."trigger_generic_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_project_url TEXT := 'https://your-project.supabase.co';
    v_fcm_secret TEXT;
BEGIN
    SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = NEW.user_id;
    IF v_recipient_fcm_token IS NOT NULL THEN
        v_fcm_secret := private.get_key('fcm_secret');
        
        BEGIN
            PERFORM net.http_post(
                url := v_project_url || '/functions/v1/send-fcm',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_fcm_secret
                ),
                body := jsonb_build_object(
                    'token', v_recipient_fcm_token,
                    'title', NEW.title,
                    'body', NEW.message,
                    'data', jsonb_build_object('type', 'notification', 'id', NEW.id)
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Generic notification failed: %', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$;

-- ────────────────────────────────────────────────────────────────
-- PART 3: DEAD / ORPHAN CODE CLEANUP
-- ────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS "public"."trigger_reward_notification"();
DROP FUNCTION IF EXISTS "public"."trigger_fcm_notification"();
DROP FUNCTION IF EXISTS "public"."trigger_chat_notification"();
DROP FUNCTION IF EXISTS "public"."fn_sync_chat_message_content"();

-- ────────────────────────────────────────────────────────────────
-- PART 4: CHAT SYSTEM STABILIZATION & RLS POLICIES REMEDIATION
-- ────────────────────────────────────────────────────────────────

-- Drop existing restricted select policies if any
DROP POLICY IF EXISTS "Social chat participants select conversations" ON "public"."chat_conversations";
DROP POLICY IF EXISTS "Social chat participants update conversations" ON "public"."chat_conversations";
DROP POLICY IF EXISTS "Social chat participants select messages" ON "public"."chat_messages";
DROP POLICY IF EXISTS "Social chat participants insert messages" ON "public"."chat_messages";

-- Allow participants of social chat to select/view the conversation
CREATE POLICY "Social chat participants select conversations" ON "public"."chat_conversations"
  FOR SELECT TO authenticated
  USING (
    category = 'social' AND (
      auth.uid() = user_low_id OR auth.uid() = user_high_id
    )
  );

-- Allow participants of social chat to update the conversation (e.g. unread counts, last message)
CREATE POLICY "Social chat participants update conversations" ON "public"."chat_conversations"
  FOR UPDATE TO authenticated
  USING (
    category = 'social' AND (
      auth.uid() = user_low_id OR auth.uid() = user_high_id
    )
  )
  WITH CHECK (
    category = 'social' AND (
      auth.uid() = user_low_id OR auth.uid() = user_high_id
    )
  );

-- Allow participants of social chat to view messages
CREATE POLICY "Social chat participants select messages" ON "public"."chat_messages"
  FOR SELECT TO authenticated
  USING (
    conversation_id IN (
      SELECT id FROM public.chat_conversations
      WHERE category = 'social'
        AND (user_low_id = auth.uid() OR user_high_id = auth.uid())
    )
  );

-- Allow participants of social chat to insert messages
CREATE POLICY "Social chat participants insert messages" ON "public"."chat_messages"
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND conversation_id IN (
      SELECT id FROM public.chat_conversations
      WHERE category = 'social'
        AND (user_low_id = auth.uid() OR user_high_id = auth.uid())
    )
  );

-- ────────────────────────────────────────────────────────────────
-- PART 5: SOCIAL CHAT ADMIN NOTIFICATION LEAK FIX
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "public"."fn_trigger_chat_push_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_target_user_id UUID;
    v_sender_name TEXT;
    v_type TEXT;
    v_deep_link TEXT;
    v_msg_text TEXT;
    v_conv_category TEXT;
BEGIN
    -- Skip system messages for push
    IF NEW.sender_type = 'system' THEN RETURN NEW; END IF;

    -- Get conversation details
    SELECT category INTO v_conv_category
    FROM public.chat_conversations WHERE id = NEW.conversation_id;

    -- Skip social chats since they are already notified to peers via handle_chat_message_logic()
    IF v_conv_category = 'social' THEN RETURN NEW; END IF;

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

-- ────────────────────────────────────────────────────────────────
-- PART 6: ATOMIC CHAT UNREAD COUNTERS & LAST MESSAGE UPDATES
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_increment_unread_counter()
RETURNS TRIGGER AS $$
DECLARE
    v_category TEXT;
    v_low_id UUID;
    v_high_id UUID;
BEGIN
    -- Fetch conversation details
    SELECT category, user_low_id, user_high_id
    INTO v_category, v_low_id, v_high_id
    FROM public.chat_conversations WHERE id = NEW.conversation_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Update last message preview and time atomically
    UPDATE public.chat_conversations
    SET last_message = CASE WHEN NEW.message_type = 'image' THEN '📷 صورة' ELSE NEW.message_content END,
        last_message_at = NEW.created_at
    WHERE id = NEW.conversation_id;

    -- Increment unread counts atomically
    IF v_category = 'social' THEN
        -- P2P: increment the OTHER participant's unread counter
        IF NEW.sender_id = v_low_id THEN
            UPDATE public.chat_conversations
            SET unread_admin_count = COALESCE(unread_admin_count, 0) + 1  -- unread count for user_high_id
            WHERE id = NEW.conversation_id;
        ELSIF NEW.sender_id = v_high_id THEN
            UPDATE public.chat_conversations
            SET unread_user_count = COALESCE(unread_user_count, 0) + 1    -- unread count for user_low_id
            WHERE id = NEW.conversation_id;
        END IF;
    ELSE
        -- Support / Agent chats
        IF NEW.sender_type IN ('user', 'agent') THEN
            -- User/Agent sends message → Admin unread count increments
            UPDATE public.chat_conversations
            SET unread_admin_count = COALESCE(unread_admin_count, 0) + 1
            WHERE id = NEW.conversation_id;
        ELSIF NEW.sender_type = 'admin' THEN
            -- Admin sends message → User unread count increments
            UPDATE public.chat_conversations
            SET unread_user_count = COALESCE(unread_user_count, 0) + 1
            WHERE id = NEW.conversation_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger AFTER INSERT to ensure count increments on success
DROP TRIGGER IF EXISTS trg_chat_message_unread_and_last_message ON public.chat_messages;
CREATE TRIGGER trg_chat_message_unread_and_last_message
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_increment_unread_counter();

-- ────────────────────────────────────────────────────────────────
-- PART 7: AUTOMATED MESSAGE READ RECEIPT TRIGGER
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_sync_message_read_status()
RETURNS TRIGGER AS $$
BEGIN
    -- If unread_admin_count was set to 0, mark peer or user/agent messages as read
    IF NEW.unread_admin_count = 0 AND OLD.unread_admin_count > 0 THEN
        IF NEW.category = 'social' THEN
            -- High user marked read: mark low user's messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_id = NEW.user_low_id
              AND read_at IS NULL;
        ELSE
            -- Admin marked read: mark user/agent messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_type IN ('user', 'agent')
              AND read_at IS NULL;
        END IF;
    END IF;

    -- If unread_user_count was set to 0, mark peer or admin messages as read
    IF NEW.unread_user_count = 0 AND OLD.unread_user_count > 0 THEN
        IF NEW.category = 'social' THEN
            -- Low user marked read: mark high user's messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_id = NEW.user_high_id
              AND read_at IS NULL;
        ELSE
            -- User marked read: mark admin messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_type = 'admin'
              AND read_at IS NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_chat_conversation_sync_read_status ON public.chat_conversations;
CREATE TRIGGER trg_chat_conversation_sync_read_status
    AFTER UPDATE OF unread_admin_count, unread_user_count ON public.chat_conversations
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_sync_message_read_status();

-- ────────────────────────────────────────────────────────────────
-- PART 8: FN_MARK_MESSAGES_READ SOCIAL CHAT SUPPORT
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "public"."fn_mark_messages_read"("p_conversation_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_admin BOOLEAN;
    v_conv RECORD;
BEGIN
    IF v_user_id IS NULL THEN RETURN; END IF;

    v_is_admin := public.is_admin();

    -- Verify access
    SELECT * INTO v_conv FROM public.chat_conversations WHERE id = p_conversation_id;
    IF NOT FOUND THEN RETURN; END IF;

    -- Security Guard for RLS and function context
    IF NOT v_is_admin 
       AND v_conv.user_id != v_user_id 
       AND v_conv.user_low_id != v_user_id 
       AND v_conv.user_high_id != v_user_id THEN 
        RETURN; 
    END IF;

    IF v_conv.category = 'social' THEN
        -- Social chat: mark messages from the OTHER person as read
        UPDATE public.chat_messages
        SET read_at = NOW()
        WHERE conversation_id = p_conversation_id
          AND sender_id != v_user_id
          AND read_at IS NULL;

        -- Clear MY unread counter
        IF v_user_id = v_conv.user_low_id THEN
            UPDATE public.chat_conversations 
            SET unread_user_count = 0
            WHERE id = p_conversation_id;
        ELSE
            UPDATE public.chat_conversations 
            SET unread_admin_count = 0
            WHERE id = p_conversation_id;
        END IF;
    ELSIF v_is_admin THEN
        -- Admin marks user/agent messages as read
        UPDATE public.chat_messages
        SET read_at = NOW()
        WHERE conversation_id = p_conversation_id
          AND sender_type IN ('user', 'agent')
          AND read_at IS NULL;

        UPDATE public.chat_conversations
        SET unread_admin_count = 0
        WHERE id = p_conversation_id;
    ELSE
        -- User marks admin messages as read
        UPDATE public.chat_messages
        SET read_at = NOW()
        WHERE conversation_id = p_conversation_id
          AND sender_type = 'admin'
          AND read_at IS NULL;

        UPDATE public.chat_conversations
        SET unread_user_count = 0
        WHERE id = p_conversation_id;
    END IF;
END;
$$;
