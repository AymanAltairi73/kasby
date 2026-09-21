-- Complete admin user purge: notifications FK, append-only transactions bypass, related rows

-- Allow service-role purge to delete immutable transaction rows
CREATE OR REPLACE FUNCTION public.fn_prevent_txn_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF COALESCE(current_setting('app.admin_purge', true), '') = 'true' THEN
      RETURN OLD;
    END IF;
    RAISE EXCEPTION 'FORBIDDEN: Transactions are append-only. Cannot delete.';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.status NOT IN ('pending', 'processing') THEN
      RAISE EXCEPTION 'FORBIDDEN: Finalized transaction cannot be modified.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_admin_purge_user_data(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted INT := 0;
  v_rows INT;
  v_conv_ids UUID[];
BEGIN
  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'user_id is required');
  END IF;

  -- Conversations (user_id is NOT NULL — delete, do not null FKs)
  SELECT ARRAY_AGG(id)
  INTO v_conv_ids
  FROM public.chat_conversations
  WHERE user_id = p_user_id
     OR user_low_id = p_user_id
     OR user_high_id = p_user_id;

  IF v_conv_ids IS NOT NULL THEN
    DELETE FROM public.chat_messages
    WHERE conversation_id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_deleted := v_deleted + v_rows;

    DELETE FROM public.chat_conversations
    WHERE id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_deleted := v_deleted + v_rows;
  END IF;

  -- Notifications referencing user as recipient or deep-link target
  DELETE FROM public.notifications
  WHERE user_id = p_user_id OR target_user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_investments WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.subscriptions WHERE user_id = p_user_id;
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

  DELETE FROM public.kyc_documents WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_activities WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.friendships
  WHERE user_low_id = p_user_id OR user_high_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  UPDATE public.profiles
  SET referred_by_id = NULL
  WHERE referred_by_id = p_user_id;

  UPDATE public.transactions
  SET counterpart_user_id = NULL
  WHERE counterpart_user_id = p_user_id;

  -- Bypass append-only guard for admin purge only (local to this transaction)
  PERFORM set_config('app.admin_purge', 'true', true);
  DELETE FROM public.transactions WHERE user_id = p_user_id;
  PERFORM set_config('app.admin_purge', '', true);
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.profiles WHERE id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  RETURN jsonb_build_object('success', true, 'deleted_rows', v_deleted);
EXCEPTION
  WHEN OTHERS THEN
    PERFORM set_config('app.admin_purge', '', true);
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_purge_user_data(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_purge_user_data(UUID) TO service_role;
