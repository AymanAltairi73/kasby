-- Fix admin/agent support messaging blocked by social friendship trigger
-- Error seen in admin app: "Messaging only allowed between friends" (P0001)

CREATE OR REPLACE FUNCTION public.handle_chat_message_logic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_conv_category TEXT;
    v_peer_id UUID;
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_msg_text TEXT;
BEGIN
    v_msg_text := NEW.message_content;

    SELECT category, user_low_id, user_high_id
    INTO v_conv_category, v_recipient_id, v_peer_id
    FROM public.chat_conversations
    WHERE id = NEW.conversation_id;

    -- Support / agent / admin paths must never hit the social friendship gate
    IF NEW.sender_type IN ('admin', 'system')
       OR public.is_admin()
       OR COALESCE(v_conv_category, '') <> 'social' THEN
        RETURN NEW;
    END IF;

    IF NEW.sender_id = v_recipient_id THEN
        v_recipient_id := v_peer_id;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.friendships
        WHERE user_low_id = LEAST(NEW.sender_id, v_recipient_id)
          AND user_high_id = GREATEST(NEW.sender_id, v_recipient_id)
    ) THEN
        RAISE EXCEPTION 'Messaging only allowed between friends';
    END IF;

    SELECT full_name INTO v_sender_name
    FROM public.profiles
    WHERE id = NEW.sender_id;

    INSERT INTO public.notifications (
        user_id, title, message, target, target_user_id, type
    ) VALUES (
        v_recipient_id,
        'رسالة جديدة من ' || COALESCE(v_sender_name, 'مستخدم'),
        CASE WHEN NEW.message_type = 'image' THEN '📷 صورة'
             ELSE LEFT(v_msg_text, 100) END,
        'chat',
        NEW.sender_id,
        'social_chat'
    );

    RETURN NEW;
END;
$$;

-- Ensure canonical fn_send_chat_message allows admin on support + agent chats
CREATE OR REPLACE FUNCTION public.fn_send_chat_message(
  p_conversation_id UUID,
  p_message_content TEXT,
  p_message_type TEXT DEFAULT 'text',
  p_idempotency_key TEXT DEFAULT NULL,
  p_reply_to_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_sender_type TEXT;
  v_conv RECORD;
  v_message_id UUID;
BEGIN
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF p_message_content IS NULL OR btrim(p_message_content) = '' THEN
    RAISE EXCEPTION 'Message content cannot be empty';
  END IF;

  SELECT *
  INTO v_conv
  FROM public.chat_conversations
  WHERE id = p_conversation_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Conversation not found';
  END IF;

  IF public.is_admin() THEN
    v_sender_type := 'admin';
  ELSIF public.is_agent() THEN
    v_sender_type := 'agent';
  ELSE
    v_sender_type := 'user';
  END IF;

  IF v_conv.category = 'social' THEN
    IF public.is_admin() THEN
      NULL;
    ELSIF v_sender_id NOT IN (v_conv.user_low_id, v_conv.user_high_id) THEN
      RAISE EXCEPTION 'Unauthorized for social conversation';
    END IF;
  ELSIF COALESCE(v_conv.is_agent_chat, false) THEN
    IF v_sender_type = 'admin' THEN
      NULL;
    ELSIF v_sender_type = 'user' THEN
      IF v_conv.user_id IS DISTINCT FROM v_sender_id THEN
        RAISE EXCEPTION 'Unauthorized for agent conversation';
      END IF;
    ELSIF v_sender_type = 'agent' THEN
      IF NOT EXISTS (
        SELECT 1
        FROM public.agents a
        WHERE a.id = v_conv.agent_id
          AND a.user_id = v_sender_id
      ) THEN
        RAISE EXCEPTION 'Unauthorized for agent conversation';
      END IF;
    ELSE
      RAISE EXCEPTION 'Unauthorized sender type';
    END IF;
  ELSE
    IF v_sender_type = 'admin' THEN
      NULL;
    ELSIF v_sender_type IN ('user', 'agent') THEN
      IF v_conv.user_id IS DISTINCT FROM v_sender_id THEN
        RAISE EXCEPTION 'Unauthorized for support conversation';
      END IF;
    ELSE
      RAISE EXCEPTION 'Unauthorized sender type';
    END IF;
  END IF;

  IF p_reply_to_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.chat_messages m
      WHERE m.id = p_reply_to_id
        AND m.conversation_id = p_conversation_id
    ) THEN
      RAISE EXCEPTION 'Invalid reply_to_id for conversation';
    END IF;
  END IF;

  INSERT INTO public.chat_messages (
    conversation_id,
    sender_id,
    sender_type,
    message_content,
    message_type,
    idempotency_key,
    reply_to_id
  ) VALUES (
    p_conversation_id,
    v_sender_id,
    v_sender_type,
    btrim(p_message_content),
    COALESCE(p_message_type, 'text')::public.message_type,
    p_idempotency_key,
    p_reply_to_id
  )
  ON CONFLICT (idempotency_key) DO NOTHING
  RETURNING id INTO v_message_id;

  IF v_message_id IS NULL AND p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_message_id
    FROM public.chat_messages
    WHERE idempotency_key = p_idempotency_key
    LIMIT 1;
  END IF;

  RETURN v_message_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_send_chat_message(UUID, TEXT, TEXT, TEXT, UUID)
  TO authenticated, service_role;
