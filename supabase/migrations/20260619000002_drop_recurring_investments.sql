-- =================================================================
-- Migration: Drop recurring investments feature
-- Date: 2026-06-19
-- Purpose: Remove recurring_investments table, RPCs, and triggers
--          after the feature was removed from the mobile app.
-- =================================================================

-- Drop scheduled-processing RPCs first (no table required)
DROP FUNCTION IF EXISTS public.process_due_recurring_investments();
DROP FUNCTION IF EXISTS public.execute_recurring_investment(uuid);

-- Drop table first (removes triggers/policies). Safe if already removed.
DROP TABLE IF EXISTS public.recurring_investments CASCADE;

-- Drop trigger helper if it still exists
DROP FUNCTION IF EXISTS public.update_recurring_investment_timestamp();

-- Keep admin hard-delete RPC valid after table removal
CREATE OR REPLACE FUNCTION public.fn_admin_hard_delete_user(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_user_name TEXT;
  v_user_email TEXT;
  v_caller_id UUID := auth.uid();
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: no authenticated session';
  END IF;

  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Forbidden: admin access required';
  END IF;

  SELECT full_name, email INTO v_user_name, v_user_email
  FROM profiles WHERE id = p_user_id;

  IF v_user_name IS NULL THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  IF p_user_id = v_caller_id THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  UPDATE notifications SET target_user_id = NULL WHERE target_user_id = p_user_id;
  UPDATE notifications SET sent_by = NULL WHERE sent_by = p_user_id;
  UPDATE transactions SET processed_by = NULL WHERE processed_by = p_user_id;
  UPDATE transactions SET counterpart_user_id = NULL WHERE counterpart_user_id = p_user_id;
  UPDATE user_investments SET approved_by = NULL WHERE approved_by = p_user_id;
  UPDATE loans SET approved_by = NULL WHERE approved_by = p_user_id;
  UPDATE kyc_documents SET reviewed_by = NULL WHERE reviewed_by = p_user_id;
  UPDATE investment_plans SET created_by = NULL WHERE created_by = p_user_id;
  UPDATE system_settings SET updated_by = NULL WHERE updated_by = p_user_id;
  UPDATE wallets SET frozen_by = NULL WHERE frozen_by = p_user_id;

  UPDATE user_investments SET locked_by_loan_id = NULL, transaction_id = NULL
    WHERE user_id = p_user_id;
  UPDATE loans SET collateral_investment_id = NULL WHERE user_id = p_user_id;
  UPDATE subscriptions SET payment_transaction_id = NULL WHERE user_id = p_user_id;

  DELETE FROM chat_internal_notes WHERE conversation_id IN (
    SELECT id FROM chat_conversations WHERE user_id = p_user_id
      OR user_low_id = p_user_id OR user_high_id = p_user_id);
  DELETE FROM chat_participants WHERE conversation_id IN (
    SELECT id FROM chat_conversations WHERE user_id = p_user_id
      OR user_low_id = p_user_id OR user_high_id = p_user_id);
  DELETE FROM chat_messages WHERE conversation_id IN (
    SELECT id FROM chat_conversations WHERE user_id = p_user_id
      OR user_low_id = p_user_id OR user_high_id = p_user_id);
  DELETE FROM chat_conversations WHERE user_id = p_user_id
    OR user_low_id = p_user_id OR user_high_id = p_user_id;

  DELETE FROM support_messages WHERE conversation_id IN (
    SELECT id FROM support_conversations WHERE user_id = p_user_id);
  DELETE FROM support_conversations WHERE user_id = p_user_id;

  DELETE FROM agent_commissions WHERE agent_id IN (
    SELECT id FROM agents WHERE user_id = p_user_id);
  DELETE FROM agents WHERE user_id = p_user_id;

  DELETE FROM loan_repayments WHERE user_id = p_user_id;
  DELETE FROM loans WHERE user_id = p_user_id;
  DELETE FROM user_investments WHERE user_id = p_user_id;
  DELETE FROM subscriptions WHERE user_id = p_user_id;
  DELETE FROM referral_earnings WHERE referrer_id = p_user_id OR investor_id = p_user_id;
  DELETE FROM pending_rewards WHERE user_id = p_user_id;
  DELETE FROM transactions WHERE user_id = p_user_id;
  DELETE FROM wallets WHERE user_id = p_user_id;
  DELETE FROM friend_requests WHERE requester_id = p_user_id OR receiver_id = p_user_id;
  DELETE FROM friendships WHERE user_low_id = p_user_id OR user_high_id = p_user_id;
  DELETE FROM notifications WHERE user_id = p_user_id;
  DELETE FROM user_activities WHERE user_id = p_user_id;
  DELETE FROM spin_history WHERE user_id = p_user_id;
  DELETE FROM spin_results WHERE user_id = p_user_id;
  DELETE FROM point_history WHERE user_id = p_user_id;
  DELETE FROM user_points WHERE user_id = p_user_id;
  DELETE FROM daily_check_ins WHERE user_id = p_user_id;
  DELETE FROM kyc_documents WHERE user_id = p_user_id;
  DELETE FROM otp_verifications WHERE user_id = p_user_id;
  DELETE FROM device_tokens WHERE user_id = p_user_id;
  DELETE FROM agent_applications WHERE user_id = p_user_id;
  DELETE FROM activity_logs WHERE actor_id = p_user_id;
  DELETE FROM system_logs WHERE actor_id = p_user_id;
  DELETE FROM audit_logs WHERE admin_id = p_user_id OR target_id = p_user_id::text;

  UPDATE profiles SET referred_by = NULL WHERE referred_by = p_user_id;
  UPDATE profiles SET referred_by_id = NULL WHERE referred_by_id = p_user_id;
  UPDATE profiles SET status_changed_by = NULL WHERE status_changed_by = p_user_id;

  DELETE FROM profiles WHERE id = p_user_id;
  DELETE FROM auth.users WHERE id = p_user_id;

  INSERT INTO activity_logs (
    actor_id, actor_role, action, entity_type, entity_id, details, severity
  ) VALUES (
    v_caller_id, 'admin', 'hard_delete_user', 'user', p_user_id::text,
    jsonb_build_object('deleted_user_name', v_user_name,
      'deleted_user_email', v_user_email, 'deleted_at', now()),
    'critical'
  );

  RETURN jsonb_build_object(
    'success', true,
    'deleted_user_id', p_user_id,
    'deleted_user_name', v_user_name,
    'deleted_user_email', v_user_email,
    'deleted_at', now()
  );
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Failed to delete user %: %', p_user_id, SQLERRM;
END;
$$;
