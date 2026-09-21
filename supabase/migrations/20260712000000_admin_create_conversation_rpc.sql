-- Allow admins to create support conversations via RPC (bypasses RLS)
-- Fixes: "new row violates row-level security policy for table chat_conversations"

CREATE OR REPLACE FUNCTION public.fn_admin_create_conversation(
  p_user_id UUID,
  p_category TEXT DEFAULT 'support',
  p_is_agent_chat BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conversation_id UUID;
  v_result JSON;
BEGIN
  -- Only admins can create conversations via this function
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Only admins can create conversations';
  END IF;

  -- Check if conversation already exists
  SELECT id INTO v_conversation_id
  FROM public.chat_conversations
  WHERE user_id = p_user_id
    AND is_agent_chat = p_is_agent_chat
    AND category = p_category
  LIMIT 1;

  -- If exists, return existing with nested profile data
  IF v_conversation_id IS NOT NULL THEN
    SELECT json_build_object(
      'id', c.id,
      'user_id', c.user_id,
      'category', c.category,
      'is_agent_chat', c.is_agent_chat,
      'last_message', c.last_message,
      'last_message_at', c.last_message_at,
      'unread_admin_count', c.unread_admin_count,
      'profiles', json_build_object(
        'full_name', p.full_name,
        'avatar_url', p.avatar_url,
        'updated_at', p.updated_at,
        'role', p.role,
        'last_seen_at', p.last_seen_at
      )
    ) INTO v_result
    FROM public.chat_conversations c
    LEFT JOIN public.profiles p ON c.user_id = p.id
    WHERE c.id = v_conversation_id;
    
    RETURN v_result;
  END IF;

  -- Create new conversation
  INSERT INTO public.chat_conversations (
    user_id,
    category,
    is_agent_chat,
    last_message_at
  ) VALUES (
    p_user_id,
    p_category,
    p_is_agent_chat,
    NOW()
  )
  RETURNING id INTO v_conversation_id;

  -- Fetch the created conversation with nested profile data
  SELECT json_build_object(
    'id', c.id,
    'user_id', c.user_id,
    'category', c.category,
    'is_agent_chat', c.is_agent_chat,
    'last_message', c.last_message,
    'last_message_at', c.last_message_at,
    'unread_admin_count', c.unread_admin_count,
    'profiles', json_build_object(
      'full_name', p.full_name,
      'avatar_url', p.avatar_url,
      'updated_at', p.updated_at,
      'role', p.role,
      'last_seen_at', p.last_seen_at
    )
  ) INTO v_result
  FROM public.chat_conversations c
  LEFT JOIN public.profiles p ON c.user_id = p.id
  WHERE c.id = v_conversation_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_create_conversation(UUID, TEXT, BOOLEAN)
  TO authenticated, service_role;
