-- Enterprise UX audit: agent chat RPC, phone recovery lookup, agent customer context

CREATE OR REPLACE FUNCTION public.recover_account_by_phone(p_phone text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_profile RECORD;
  v_phone text := trim(p_phone);
BEGIN
  IF v_phone IS NULL OR v_phone = '' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Invalid phone');
  END IF;

  SELECT id, email, phone, full_name INTO v_profile
  FROM public.profiles
  WHERE phone = v_phone
     OR phone = regexp_replace(v_phone, '^\+', '')
     OR ('+' || phone) = v_phone
  LIMIT 1;

  IF v_profile IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'message', 'No account associated with this phone'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_profile.id,
    'phone', v_profile.phone,
    'full_name', v_profile.full_name,
    'message', 'Account found'
  );
END;
$$;

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
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_get_agent_customer_details(
  p_user_id uuid,
  p_transaction_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_id uuid;
  v_profile jsonb;
  v_wallet_balance numeric;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_agent() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT id INTO v_agent_id
  FROM public.agents
  WHERE user_id = auth.uid()
  LIMIT 1;

  IF v_agent_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Agent profile not found');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.transactions t
    WHERE t.user_id = p_user_id
      AND t.reference_id = v_agent_id::text
      AND (p_transaction_id IS NULL OR t.id = p_transaction_id)
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Customer not assigned');
  END IF;

  SELECT row_to_json(p)::jsonb INTO v_profile
  FROM (
    SELECT
      id,
      full_name,
      referral_code,
      phone,
      avatar_url,
      status,
      kyc_status,
      created_at,
      last_seen_at
    FROM public.profiles
    WHERE id = p_user_id
  ) p;

  SELECT w.available_balance INTO v_wallet_balance
  FROM public.wallets w
  WHERE w.user_id = p_user_id
  ORDER BY w.created_at
  LIMIT 1;

  RETURN jsonb_build_object(
    'success', true,
    'profile', v_profile,
    'wallet_balance', COALESCE(v_wallet_balance, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.recover_account_by_phone(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_start_agent_chat(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_get_agent_customer_details(uuid, uuid) TO authenticated, service_role;
