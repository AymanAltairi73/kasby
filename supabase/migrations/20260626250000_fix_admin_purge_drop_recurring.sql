-- Fix admin user purge after recurring_investments table was dropped (20260619000002).
-- Removes reference to recurring_investments and keeps comprehensive purge logic.

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

  PERFORM set_config('app.admin_purge', 'true', true);

  UPDATE public.notifications SET target_user_id = NULL WHERE target_user_id = p_user_id;
  UPDATE public.notifications SET sent_by = NULL WHERE sent_by = p_user_id;
  UPDATE public.transactions SET processed_by = NULL WHERE processed_by = p_user_id;
  UPDATE public.transactions SET counterpart_user_id = NULL WHERE counterpart_user_id = p_user_id;
  UPDATE public.user_investments SET approved_by = NULL WHERE approved_by = p_user_id;
  UPDATE public.loans SET approved_by = NULL WHERE approved_by = p_user_id;
  UPDATE public.kyc_documents SET reviewed_by = NULL WHERE reviewed_by = p_user_id;
  UPDATE public.investment_plans SET created_by = NULL WHERE created_by = p_user_id;
  UPDATE public.system_settings SET updated_by = NULL WHERE updated_by = p_user_id;
  UPDATE public.wallets SET frozen_by = NULL WHERE frozen_by = p_user_id;
  UPDATE public.profiles SET status_changed_by = NULL WHERE status_changed_by = p_user_id;
  UPDATE public.profiles SET referred_by_id = NULL WHERE referred_by_id = p_user_id;
  UPDATE public.profiles SET referred_by = NULL WHERE referred_by = p_user_id;
  UPDATE public.chat_conversations SET assigned_admin_id = NULL WHERE assigned_admin_id = p_user_id;

  UPDATE public.user_investments
     SET locked_by_loan_id = NULL, transaction_id = NULL
   WHERE user_id = p_user_id;
  UPDATE public.loans SET collateral_investment_id = NULL WHERE user_id = p_user_id;
  UPDATE public.subscriptions SET payment_transaction_id = NULL WHERE user_id = p_user_id;

  DELETE FROM public.system_logs WHERE actor_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.audit_logs
    WHERE admin_id = p_user_id OR entity_id = p_user_id OR target_id = p_user_id::text;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.activity_logs WHERE actor_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  SELECT ARRAY_AGG(id) INTO v_conv_ids
  FROM public.chat_conversations
  WHERE user_id = p_user_id OR user_low_id = p_user_id OR user_high_id = p_user_id;

  IF v_conv_ids IS NOT NULL THEN
    DELETE FROM public.chat_internal_notes WHERE conversation_id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

    DELETE FROM public.chat_participants WHERE conversation_id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

    DELETE FROM public.chat_messages WHERE conversation_id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

    DELETE FROM public.chat_conversations WHERE id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;
  END IF;

  DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.support_messages WHERE conversation_id IN (
    SELECT id FROM public.support_conversations WHERE user_id = p_user_id
  );
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.support_conversations WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.agent_commissions WHERE agent_id IN (
    SELECT id FROM public.agents WHERE user_id = p_user_id
  );
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.loan_repayments WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.loans WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_investments WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.subscriptions WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.referral_earnings
    WHERE referrer_id = p_user_id OR investor_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.pending_rewards WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.transactions WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.wallets WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.friend_requests
    WHERE requester_id = p_user_id OR receiver_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.friendships
    WHERE user_low_id = p_user_id OR user_high_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.notifications WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_activities WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.spin_history WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.spin_results WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.point_history WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_points WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.daily_check_ins WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.kyc_documents WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.otp_verifications WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.device_tokens WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.agent_applications WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.agents WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  DELETE FROM public.profiles WHERE id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT; v_deleted := v_deleted + v_rows;

  PERFORM set_config('app.admin_purge', '', true);

  RETURN jsonb_build_object('success', true, 'deleted_rows', v_deleted);
EXCEPTION
  WHEN OTHERS THEN
    PERFORM set_config('app.admin_purge', '', true);
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

REVOKE ALL ON FUNCTION public.fn_admin_purge_user_data(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_purge_user_data(UUID) TO service_role;
