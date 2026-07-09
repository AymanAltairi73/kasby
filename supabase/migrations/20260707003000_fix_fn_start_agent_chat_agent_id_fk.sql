-- Fix fn_start_agent_chat: chat_conversations.agent_id FK references agents(id), not agents.user_id.
-- Fix agent chat RLS policies to match agents.id semantics.

CREATE OR REPLACE FUNCTION public.fn_start_agent_chat(p_agent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_agent_user_id uuid;
  v_agent_status text;
  v_conv_id uuid;
  v_conv_record RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT a.user_id, a.status
  INTO v_agent_user_id, v_agent_status
  FROM public.agents a
  WHERE a.id = p_agent_id;

  IF v_agent_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Agent not found');
  END IF;

  IF v_agent_status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Agent not active');
  END IF;

  IF v_agent_user_id = v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot chat with yourself');
  END IF;

  -- agent_id column stores agents.id (FK), NOT agents.user_id
  SELECT id INTO v_conv_id
  FROM public.chat_conversations
  WHERE user_id = v_user_id
    AND agent_id = p_agent_id
    AND is_agent_chat = true
    AND is_closed = false
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_conv_id IS NULL THEN
    INSERT INTO public.chat_conversations (
      user_id,
      agent_id,
      category,
      is_agent_chat,
      conversation_type
    )
    VALUES (
      v_user_id,
      p_agent_id,
      'agent',
      true,
      'agent'
    )
    RETURNING id INTO v_conv_id;
  END IF;

  SELECT * INTO v_conv_record
  FROM public.chat_conversations
  WHERE id = v_conv_id;

  RETURN jsonb_build_object(
    'success', true,
    'conversation', row_to_json(v_conv_record)
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'sqlstate', SQLSTATE
    );
END;
$$;

-- Agent-side read access: match agent record id, not auth uid directly on agent_id column
DROP POLICY IF EXISTS "Agents view agent chats" ON public.chat_conversations;
CREATE POLICY "Agents view agent chats"
ON public.chat_conversations
FOR SELECT
TO authenticated
USING (
  is_agent_chat = true
  AND agent_id IN (
    SELECT id FROM public.agents WHERE user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Agents view agent messages" ON public.chat_messages;
CREATE POLICY "Agents view agent messages"
ON public.chat_messages
FOR SELECT
TO authenticated
USING (
  conversation_id IN (
    SELECT id
    FROM public.chat_conversations
    WHERE is_agent_chat = true
      AND agent_id IN (
        SELECT id FROM public.agents WHERE user_id = auth.uid()
      )
  )
);

GRANT EXECUTE ON FUNCTION public.fn_start_agent_chat(uuid) TO authenticated, service_role;
