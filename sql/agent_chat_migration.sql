-- 1. Update fn_send_chat_message
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
    -- FIX: Validate agent authorization correctly via agents.user_id
    ELSIF v_conv.is_agent_chat AND EXISTS (SELECT 1 FROM public.agents WHERE id = v_conv.agent_id AND user_id = v_user_id) THEN
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

    -- Insert message
    INSERT INTO public.chat_messages (
        conversation_id, sender_id, sender_type, message_content,
        message_type, reply_to_id, idempotency_key
    ) VALUES (
        p_conversation_id, v_user_id, v_sender_type,
        p_message_content, p_message_type, p_reply_to_id, p_idempotency_key
    )
    RETURNING id INTO v_msg_id;

    -- Update conversation metadata
    UPDATE public.chat_conversations
    SET last_message = v_display_text,
        last_message_at = NOW(),
        unread_admin_count = CASE WHEN v_sender_type = 'user' THEN unread_admin_count + 1 ELSE unread_admin_count END,
        unread_user_count = CASE WHEN v_sender_type = 'admin' THEN unread_user_count + 1 ELSE unread_user_count END
    WHERE id = p_conversation_id;

    RETURN v_msg_id;
END;
$$;

-- 2. Create fn_start_agent_chat
CREATE OR REPLACE FUNCTION public.fn_start_agent_chat(p_agent_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_agent_user_id UUID;
    v_conv RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- Verify agent exists
    SELECT user_id INTO v_agent_user_id FROM public.agents WHERE id = p_agent_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Agent not found');
    END IF;

    -- Prevent agents from chatting with themselves
    IF v_agent_user_id = v_user_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot chat with yourself');
    END IF;

    -- Look for existing active conversation
    SELECT * INTO v_conv
    FROM public.chat_conversations
    WHERE user_id = v_user_id
      AND is_agent_chat = true
      AND agent_id = p_agent_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object('success', true, 'conversation', row_to_json(v_conv));
    END IF;

    -- Create new agent conversation
    INSERT INTO public.chat_conversations (
        user_id,
        is_agent_chat,
        agent_id,
        status,
        is_closed
    ) VALUES (
        v_user_id,
        true,
        p_agent_id,
        'open',
        false
    ) RETURNING * INTO v_conv;

    RETURN jsonb_build_object('success', true, 'conversation', row_to_json(v_conv));
END;
$$;

GRANT ALL ON FUNCTION public.fn_start_agent_chat(UUID) TO authenticated;

-- 3. Update RLS Policies
DROP POLICY IF EXISTS "Agents view agent chats" ON public.chat_conversations;
CREATE POLICY "Agents view agent chats" ON public.chat_conversations
FOR SELECT TO authenticated
USING (
  is_agent_chat = true 
  AND EXISTS (SELECT 1 FROM public.agents WHERE id = chat_conversations.agent_id AND user_id = auth.uid())
);

DROP POLICY IF EXISTS "Agents view agent messages" ON public.chat_messages;
CREATE POLICY "Agents view agent messages" ON public.chat_messages
FOR SELECT TO authenticated
USING (
  conversation_id IN (
    SELECT id FROM public.chat_conversations 
    WHERE is_agent_chat = true 
    AND EXISTS (SELECT 1 FROM public.agents WHERE id = chat_conversations.agent_id AND user_id = auth.uid())
  )
);
