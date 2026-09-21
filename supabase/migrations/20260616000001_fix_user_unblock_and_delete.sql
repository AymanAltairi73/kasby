-- Fix admin user unblock (notification type constraint) and delete (system_logs immutability)

-- ─── 1. Allow admin-management notification types ───────────────────────────
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IS NULL OR type IN (
        'deposit_submitted', 'deposit_approved', 'deposit_rejected',
        'withdrawal_requested', 'withdrawal_approved', 'withdrawal_rejected', 'withdrawal_completed',
        'transfer_received', 'transfer_sent',
        'loan_requested', 'loan_approved', 'loan_rejected',
        'loan_repayment_due', 'loan_overdue', 'loan_paid',
        'investment_created', 'daily_profit', 'investment_matured', 'investment_cancelled',
        'chat_new_message', 'chat_admin_reply', 'chat_resolved', 'chat_escalated',
        'kyc_approved', 'kyc_rejected', 'account_flagged', 'account_frozen',
        'account_unblocked', 'profile_updated', 'account_deleted',
        'role_upgraded', 'referral_bonus',
        'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change',
        'admin_kyc_pending', 'admin_withdrawal_pending', 'admin_deposit_pending',
        'admin_flagged_user', 'admin_new_chat',
        'social_friend_request', 'social_friend_accepted', 'social_chat',
        'system', 'maintenance', 'announcement', 'security_alert',
        'info', 'success', 'warning', 'critical', 'reward', 'notification',
        'wheel_reminder', 'checkin_reminder'
    ));

-- ─── 2. Allow system_logs purge during admin user deletion ───────────────────
CREATE OR REPLACE FUNCTION public.fn_prevent_syslog_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF COALESCE(current_setting('app.admin_purge', true), '') = 'true' THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END IF;

    RAISE EXCEPTION 'FORBIDDEN: System logs are immutable. Cannot %, only INSERT.', TG_OP;
END;
$$;

-- ─── 3. Robust admin user purge (logs + FK cleanup before auth delete) ───────
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

  -- Remove immutable logs that block auth.users DELETE (ON DELETE SET NULL)
  DELETE FROM public.system_logs WHERE actor_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.audit_logs
  WHERE admin_id = p_user_id OR entity_id = p_user_id OR target_id = p_user_id::text;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  -- Clear nullable admin/user cross-references
  UPDATE public.transactions SET processed_by = NULL WHERE processed_by = p_user_id;
  UPDATE public.transactions SET counterpart_user_id = NULL WHERE counterpart_user_id = p_user_id;
  UPDATE public.notifications SET sent_by = NULL WHERE sent_by = p_user_id;
  UPDATE public.kyc_documents SET reviewed_by = NULL WHERE reviewed_by = p_user_id;
  UPDATE public.user_investments SET approved_by = NULL WHERE approved_by = p_user_id;
  UPDATE public.loans SET approved_by = NULL WHERE approved_by = p_user_id;
  UPDATE public.wallets SET frozen_by = NULL WHERE frozen_by = p_user_id;
  UPDATE public.profiles SET status_changed_by = NULL WHERE status_changed_by = p_user_id;
  UPDATE public.profiles SET referred_by_id = NULL WHERE referred_by_id = p_user_id;
  UPDATE public.profiles SET referred_by = NULL WHERE referred_by = p_user_id;

  UPDATE public.chat_conversations SET assigned_admin_id = NULL WHERE assigned_admin_id = p_user_id;

  SELECT ARRAY_AGG(id)
  INTO v_conv_ids
  FROM public.chat_conversations
  WHERE user_id = p_user_id
     OR user_low_id = p_user_id
     OR user_high_id = p_user_id;

  IF v_conv_ids IS NOT NULL THEN
    DELETE FROM public.chat_messages WHERE conversation_id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_deleted := v_deleted + v_rows;

    DELETE FROM public.chat_conversations WHERE id = ANY(v_conv_ids);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_deleted := v_deleted + v_rows;
  END IF;

  DELETE FROM public.notifications
  WHERE user_id = p_user_id OR target_user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.chat_messages WHERE sender_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.friend_requests
  WHERE requester_id = p_user_id OR receiver_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.friendships
  WHERE user_low_id = p_user_id OR user_high_id = p_user_id;
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

  DELETE FROM public.loan_repayments WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.agents WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.agent_applications WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.user_points WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.point_history WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.daily_check_ins WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.spin_results WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.spin_history WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.pending_rewards WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.referral_earnings
  WHERE referrer_id = p_user_id OR investor_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.device_tokens WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.otp_verifications WHERE user_id = p_user_id;
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

  DELETE FROM public.transactions WHERE user_id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

  DELETE FROM public.profiles WHERE id = p_user_id;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  v_deleted := v_deleted + v_rows;

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
