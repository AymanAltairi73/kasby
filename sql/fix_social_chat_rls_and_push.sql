-- ==============================================================================
-- KASBY — Social P2P chat: RLS access + push notification routing
-- Run on Supabase after social_field_rename_migration.sql
-- ==============================================================================

-- 1. Allow both friends to read/update their social conversation
DROP POLICY IF EXISTS p_user_select_conv ON public.chat_conversations;
CREATE POLICY p_user_select_conv ON public.chat_conversations
    FOR SELECT USING (
        user_id = auth.uid()
        OR auth.uid() = user_low_id
        OR auth.uid() = user_high_id
    );

DROP POLICY IF EXISTS p_user_update_conv ON public.chat_conversations;
CREATE POLICY p_user_update_conv ON public.chat_conversations
    FOR UPDATE USING (
        user_id = auth.uid()
        OR auth.uid() = user_low_id
        OR auth.uid() = user_high_id
    );

-- 2. Messages: participants in support OR social conversations
DROP POLICY IF EXISTS p_user_select_msgs ON public.chat_messages;
CREATE POLICY p_user_select_msgs ON public.chat_messages
    FOR SELECT USING (
        conversation_id IN (
            SELECT id FROM public.chat_conversations
            WHERE user_id = auth.uid()
               OR auth.uid() = user_low_id
               OR auth.uid() = user_high_id
        )
    );

DROP POLICY IF EXISTS p_user_insert_msgs ON public.chat_messages;
CREATE POLICY p_user_insert_msgs ON public.chat_messages
    FOR INSERT WITH CHECK (
        sender_id = auth.uid()
        AND conversation_id IN (
            SELECT id FROM public.chat_conversations
            WHERE user_id = auth.uid()
               OR auth.uid() = user_low_id
               OR auth.uid() = user_high_id
        )
    );

-- 3. Push trigger: route social messages to the friend, not admins
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
    v_category TEXT;
    v_low UUID;
    v_high UUID;
BEGIN
    IF NEW.sender_type = 'system' THEN RETURN NEW; END IF;

    v_msg_text := NEW.message_content;

    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;
    IF v_sender_name IS NULL THEN v_sender_name := 'كاسبي'; END IF;

    SELECT category, user_low_id, user_high_id, user_id
    INTO v_category, v_low, v_high, v_target_user_id
    FROM public.chat_conversations WHERE id = NEW.conversation_id;

    -- P2P social chat
    IF v_category = 'social' AND v_low IS NOT NULL AND v_high IS NOT NULL THEN
        IF NEW.sender_id = v_low THEN
            v_target_user_id := v_high;
        ELSE
            v_target_user_id := v_low;
        END IF;

        IF v_target_user_id IS NOT NULL AND v_target_user_id != NEW.sender_id THEN
            PERFORM public.fn_create_notification(
                v_target_user_id,
                'رسالة جديدة من ' || v_sender_name,
                CASE WHEN NEW.message_type = 'image' THEN '📷 صورة'
                     ELSE LEFT(v_msg_text, 80) END,
                'social_chat', 'chat', NEW.conversation_id::TEXT, '/social-chat'
            );
        END IF;
        RETURN NEW;
    END IF;

    -- Support chat (existing behaviour)
    IF NEW.sender_type = 'admin' THEN
        SELECT user_id INTO v_target_user_id
        FROM public.chat_conversations WHERE id = NEW.conversation_id;
        v_type := 'chat_admin_reply';
        v_deep_link := '/support-chat';
    ELSIF NEW.sender_type IN ('user', 'agent') THEN
        SELECT assigned_admin_id INTO v_target_user_id
        FROM public.chat_conversations WHERE id = NEW.conversation_id;

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

DROP TRIGGER IF EXISTS trg_chat_push ON public.chat_messages;
CREATE TRIGGER trg_chat_push
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_trigger_chat_push_notification();
