-- Auto-provision agents row for profiles with role = agent but missing agents record.

CREATE OR REPLACE FUNCTION public.ensure_agent_profile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles%ROWTYPE;
  v_agent_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profile not found');
  END IF;

  IF v_profile.role IS DISTINCT FROM 'agent' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not an agent account');
  END IF;

  SELECT id INTO v_agent_id
  FROM public.agents
  WHERE user_id = v_user_id
  LIMIT 1;

  IF v_agent_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'agent_id', v_agent_id,
      'created', false
    );
  END IF;

  INSERT INTO public.agents (
    user_id,
    name,
    phone,
    email,
    country,
    province,
    city,
    address,
    whatsapp,
    telegram,
    status,
    is_available_now,
    availability_status
  ) VALUES (
    v_user_id,
    COALESCE(NULLIF(TRIM(v_profile.full_name), ''), 'Agent'),
    COALESCE(v_profile.phone, ''),
    COALESCE(v_profile.email, ''),
    COALESCE(v_profile.country, ''),
    COALESCE(v_profile.province, ''),
    COALESCE(v_profile.city, ''),
    COALESCE(v_profile.address, ''),
    COALESCE(v_profile.whatsapp, ''),
    COALESCE(v_profile.telegram, ''),
    'active',
    false,
    'available'
  )
  RETURNING id INTO v_agent_id;

  RETURN jsonb_build_object(
    'success', true,
    'agent_id', v_agent_id,
    'created', true
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_agent_profile() TO authenticated;
