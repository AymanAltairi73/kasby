-- ============================================================================
-- Kasby Admin App — Runtime Fixes
-- Notifications target constraint, social chat admin access, RLS for ads &
-- investment_plans, is_admin() alignment, user purge before auth delete
-- ============================================================================

-- ── is_admin(): honor admin_profiles as well as profiles.role ──
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN FALSE;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RETURN TRUE;
  END IF;

  IF to_regclass('public.admin_profiles') IS NOT NULL THEN
    RETURN EXISTS (
      SELECT 1 FROM public.admin_profiles
      WHERE id = auth.uid()
        AND COALESCE(is_active, TRUE) = TRUE
        AND role IN ('admin', 'superadmin')
    );
  END IF;

  RETURN FALSE;
END;
$$;

-- ── Bulk notifications: normalize segment targets to allowed CHECK values ──
CREATE OR REPLACE FUNCTION public.fn_create_bulk_notification(
  p_user_ids UUID[],
  p_title TEXT,
  p_message TEXT,
  p_target TEXT DEFAULT 'all',
  p_sent_by UUID DEFAULT NULL,
  p_status TEXT DEFAULT 'sent',
  p_scheduled_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT := 0;
  v_uid UUID;
  v_sent_at TIMESTAMPTZ := COALESCE(p_scheduled_at, NOW());
  v_target TEXT;
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN 0;
  END IF;

  v_target := CASE
    WHEN p_target IN ('all', 'specific', 'social', 'chat') THEN p_target
    ELSE 'specific'
  END;

  FOREACH v_uid IN ARRAY p_user_ids LOOP
    INSERT INTO public.notifications (
      user_id, title, message, target, type, sent_at, status, sent_by
    ) VALUES (
      v_uid, p_title, p_message, v_target, 'notification', v_sent_at, p_status, p_sent_by
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_bulk_notification(UUID[], TEXT, TEXT, TEXT, UUID, TEXT, TIMESTAMPTZ)
  TO authenticated, service_role;

-- ── Social chat: allow admins to send in social conversations ──
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

-- ── RLS: ads (admin full access) ──
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin full access ads" ON public.ads;
CREATE POLICY "Admin full access ads" ON public.ads
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Anyone view active ads" ON public.ads;
CREATE POLICY "Anyone view active ads" ON public.ads
  FOR SELECT TO authenticated, anon
  USING (is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW()));

-- ── RLS: investment_plans (admin manage, users read active) ──
ALTER TABLE public.investment_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin manage investment plans" ON public.investment_plans;
CREATE POLICY "Admin manage investment plans" ON public.investment_plans
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Anyone can view active plans" ON public.investment_plans;
CREATE POLICY "Anyone can view active plans" ON public.investment_plans
  FOR SELECT TO authenticated, anon
  USING (is_active = TRUE);

-- ── Purge user-owned rows before auth delete (service_role via admin-proxy) ──
CREATE OR REPLACE FUNCTION public.fn_admin_purge_user_data(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted INT := 0;
  v_rows INT;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'user_id is required');
  END IF;

  DELETE FROM public.notifications WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_investments WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.transactions WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.loans WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.agents WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_points WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.wallets WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  UPDATE public.chat_conversations
  SET user_id = NULL
  WHERE user_id = p_user_id;

  UPDATE public.chat_conversations
  SET user_low_id = NULL
  WHERE user_low_id = p_user_id;

  UPDATE public.chat_conversations
  SET user_high_id = NULL
  WHERE user_high_id = p_user_id;

  DELETE FROM public.profiles WHERE id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  RETURN jsonb_build_object('success', true, 'deleted_rows', v_deleted);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_purge_user_data(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_purge_user_data(UUID) TO service_role;
