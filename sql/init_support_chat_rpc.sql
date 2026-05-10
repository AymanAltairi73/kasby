-- ==============================================================================
-- KASBY — SUPPORT CHAT INITIALIZATION RPC
-- ==============================================================================
-- Purpose: Atomically initialize or retrieve a support conversation and 
--          insert a localized welcome message if it's new.
-- ==============================================================================

-- 0. Fix Constraints (ensure sender_id can be NULL for system messages)
ALTER TABLE public.chat_messages 
    ALTER COLUMN sender_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.fn_init_support_chat(p_language TEXT DEFAULT 'ar')
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_conv_id UUID;
    v_msg_count INT;
    v_welcome_text TEXT;
    v_conv_record RECORD;
BEGIN
    -- 1. Security Check
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    -- 2. Get or Create Conversation
    SELECT id INTO v_conv_id
    FROM public.chat_conversations
    WHERE user_id = v_user_id
      AND is_agent_chat = FALSE
      AND is_closed = FALSE
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_conv_id IS NULL THEN
        INSERT INTO public.chat_conversations (user_id, category, is_agent_chat)
        VALUES (v_user_id, 'support', FALSE)
        RETURNING id INTO v_conv_id;
    END IF;

    -- 3. Check for existing messages
    SELECT COUNT(*) INTO v_msg_count
    FROM public.chat_messages
    WHERE conversation_id = v_conv_id;

    -- 4. Insert Welcome Message if new (count = 0)
    IF v_msg_count = 0 THEN
        -- Determine localized text
        IF p_language = 'en' THEN
            v_welcome_text := 'Welcome to Kasby Support 👋' || E'\n' || 
                             'We’re here to help you with any questions or issues.' || E'\n' || 
                             'Feel free to start the conversation, and our team will assist you as soon as possible.';
        ELSE
            v_welcome_text := 'مرحباً بك في دعم كاسبي 👋' || E'\n' || 
                             'نحن هنا لمساعدتك في أي استفسار أو مشكلة.' || E'\n' || 
                             'ابدأ المحادثة وسنقوم بالرد عليك في أقرب وقت ممكن.';
        END IF;

        INSERT INTO public.chat_messages (
            conversation_id,
            sender_id,
            sender_type,
            message_content,
            message_type
        ) VALUES (
            v_conv_id,
            NULL,       -- System/Admin messages often have NULL sender_id
            'admin',
            v_welcome_text,
            'text'
        );

        -- Update last_message on conversation
        UPDATE public.chat_conversations
        SET last_message = LEFT(v_welcome_text, 100),
            last_message_at = NOW(),
            unread_user_count = 1
        WHERE id = v_conv_id;
    END IF;

    -- 5. Return Conversation Details
    SELECT * INTO v_conv_record FROM public.chat_conversations WHERE id = v_conv_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'conversation', row_to_json(v_conv_record)
    );
END;
$$;
