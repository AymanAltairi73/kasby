-- =====================================================================================
-- Migration: Canonical fn_send_chat_message + support chat insert policies
-- Purpose:
--   1. Remove obsolete RPC overloads with mismatched signatures
--   2. Publish ONE production fn_send_chat_message matching Flutter clients
--   3. Ensure reply_to_id column exists
--   4. Add missing support/agent insert RLS for direct client inserts
-- =====================================================================================

-- Ensure reply_to_id exists (used by admin + consumer reply feature)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL;

-- Normalize legacy content column name if still present
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chat_messages' AND column_name = 'content'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'chat_messages' AND column_name = 'message_content'
  ) THEN
    ALTER TABLE public.chat_messages RENAME COLUMN content TO message_content;
  END IF;
END $$;

ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS message_content TEXT;

CREATE INDEX IF NOT EXISTS idx_chat_messages_reply_to_id
  ON public.chat_messages (reply_to_id)
  WHERE reply_to_id IS NOT NULL;

-- Drop ALL legacy overloads to prevent PostgREST ambiguity (PGRST203)
DROP FUNCTION IF EXISTS public.fn_send_chat_message(UUID, UUID, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.fn_send_chat_message(UUID, TEXT, TEXT, UUID, TEXT);
DROP FUNCTION IF EXISTS public.fn_send_chat_message(UUID, UUID, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.fn_send_chat_message(UUID, TEXT, TEXT, TEXT);

-- Canonical RPC — matches kasby_admin ChatRepository params exactly:
--   p_conversation_id, p_message_content, p_message_type, p_idempotency_key, p_reply_to_id
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

  -- Resolve sender role
  IF public.is_admin() THEN
    v_sender_type := 'admin';
  ELSIF public.is_agent() THEN
    v_sender_type := 'agent';
  ELSE
    v_sender_type := 'user';
  END IF;

  -- Authorization by conversation category
  IF v_conv.category = 'social' THEN
    IF v_sender_id NOT IN (v_conv.user_low_id, v_conv.user_high_id) THEN
      RAISE EXCEPTION 'Unauthorized for social conversation';
    END IF;
  ELSE
    IF v_sender_type = 'admin' THEN
      -- Admins may reply in any support/agent conversation
      NULL;
    ELSIF v_sender_type IN ('user', 'agent') THEN
      IF v_conv.user_id IS DISTINCT FROM v_sender_id THEN
        RAISE EXCEPTION 'Unauthorized for support conversation';
      END IF;
    ELSE
      RAISE EXCEPTION 'Unauthorized sender type';
    END IF;
  END IF;

  -- Validate reply target belongs to same conversation
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

  -- Idempotent insert; unread counters handled by trg_chat_message_unread_and_last_message
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
    COALESCE(p_message_type, 'text'),
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

-- Support/agent direct inserts (consumer app path) — social insert policy already exists
DROP POLICY IF EXISTS "Support chat participants insert messages" ON public.chat_messages;
CREATE POLICY "Support chat participants insert messages" ON public.chat_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND sender_type IN ('user', 'agent')
    AND conversation_id IN (
      SELECT id
      FROM public.chat_conversations
      WHERE category IS DISTINCT FROM 'social'
        AND user_id = auth.uid()
    )
  );

-- Admin direct insert path (fallback when RPC unavailable)
DROP POLICY IF EXISTS "Admin insert chat messages" ON public.chat_messages;
CREATE POLICY "Admin insert chat messages" ON public.chat_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND sender_type = 'admin'
    AND public.is_admin()
    AND conversation_id IN (
      SELECT id FROM public.chat_conversations
    )
  );
