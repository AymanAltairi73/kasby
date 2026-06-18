-- =================================================================
-- Migration: Fix User Deletion Architecture
-- Date: 2026-06-18
-- Purpose: Redesign all FK constraints and RPC functions to enable
--          clean, production-ready hard deletion of user accounts.
-- =================================================================

-- ============================================
-- PHASE 1: Fix FK constraints on profiles.id
-- Change blocking NO ACTION/RESTRICT to
-- CASCADE (user-owned data) or
-- SET NULL (cross-reference / admin columns)
-- ============================================

-- agents.user_id: NO ACTION → CASCADE
ALTER TABLE agents DROP CONSTRAINT IF EXISTS agents_user_id_fkey;
ALTER TABLE agents ADD CONSTRAINT agents_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- chat_conversations.user_id: RESTRICT → CASCADE
ALTER TABLE chat_conversations DROP CONSTRAINT IF EXISTS chat_conversations_user_id_fkey;
ALTER TABLE chat_conversations ADD CONSTRAINT chat_conversations_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- user_activities.user_id: RESTRICT → CASCADE
ALTER TABLE user_activities DROP CONSTRAINT IF EXISTS user_activities_user_id_fkey;
ALTER TABLE user_activities ADD CONSTRAINT user_activities_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- notifications.target_user_id: NO ACTION → SET NULL
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_target_user_id_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_target_user_id_fkey
  FOREIGN KEY (target_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

-- notifications.sent_by: NO ACTION → SET NULL
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_sent_by_fkey;
ALTER TABLE notifications ADD CONSTRAINT notifications_sent_by_fkey
  FOREIGN KEY (sent_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- transactions.processed_by: NO ACTION → SET NULL
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_processed_by_fkey;
ALTER TABLE transactions ADD CONSTRAINT transactions_processed_by_fkey
  FOREIGN KEY (processed_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- transactions.counterpart_user_id: NO ACTION → SET NULL
ALTER TABLE transactions DROP CONSTRAINT IF EXISTS transactions_counterpart_user_id_fkey;
ALTER TABLE transactions ADD CONSTRAINT transactions_counterpart_user_id_fkey
  FOREIGN KEY (counterpart_user_id) REFERENCES profiles(id) ON DELETE SET NULL;

-- user_investments.approved_by: NO ACTION → SET NULL
ALTER TABLE user_investments DROP CONSTRAINT IF EXISTS user_investments_approved_by_fkey;
ALTER TABLE user_investments ADD CONSTRAINT user_investments_approved_by_fkey
  FOREIGN KEY (approved_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- loans.approved_by: NO ACTION → SET NULL
ALTER TABLE loans DROP CONSTRAINT IF EXISTS loans_approved_by_fkey;
ALTER TABLE loans ADD CONSTRAINT loans_approved_by_fkey
  FOREIGN KEY (approved_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- kyc_documents.reviewed_by: NO ACTION → SET NULL
ALTER TABLE kyc_documents DROP CONSTRAINT IF EXISTS kyc_documents_reviewed_by_fkey;
ALTER TABLE kyc_documents ADD CONSTRAINT kyc_documents_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- investment_plans.created_by: NO ACTION → SET NULL
ALTER TABLE investment_plans DROP CONSTRAINT IF EXISTS investment_plans_created_by_fkey;
ALTER TABLE investment_plans ADD CONSTRAINT investment_plans_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- system_settings.updated_by: NO ACTION → SET NULL
ALTER TABLE system_settings DROP CONSTRAINT IF EXISTS system_settings_updated_by_fkey;
ALTER TABLE system_settings ADD CONSTRAINT system_settings_updated_by_fkey
  FOREIGN KEY (updated_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- wallets.frozen_by: NO ACTION → SET NULL
ALTER TABLE wallets DROP CONSTRAINT IF EXISTS wallets_frozen_by_fkey;
ALTER TABLE wallets ADD CONSTRAINT wallets_frozen_by_fkey
  FOREIGN KEY (frozen_by) REFERENCES profiles(id) ON DELETE SET NULL;

-- ============================================
-- PHASE 2: Fix cross-table FK dependencies
-- ============================================

-- chat_messages → chat_conversations: RESTRICT → CASCADE
ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chat_messages_conversation_id_fkey;
ALTER TABLE chat_messages ADD CONSTRAINT chat_messages_conversation_id_fkey
  FOREIGN KEY (conversation_id) REFERENCES chat_conversations(id) ON DELETE CASCADE;

-- Break circular: loans ↔ user_investments
ALTER TABLE loans DROP CONSTRAINT IF EXISTS loans_collateral_investment_id_fkey;
ALTER TABLE loans ADD CONSTRAINT loans_collateral_investment_id_fkey
  FOREIGN KEY (collateral_investment_id) REFERENCES user_investments(id) ON DELETE SET NULL;

ALTER TABLE user_investments DROP CONSTRAINT IF EXISTS user_investments_locked_by_loan_id_fkey;
ALTER TABLE user_investments ADD CONSTRAINT user_investments_locked_by_loan_id_fkey
  FOREIGN KEY (locked_by_loan_id) REFERENCES loans(id) ON DELETE SET NULL;

ALTER TABLE user_investments DROP CONSTRAINT IF EXISTS user_investments_transaction_id_fkey;
ALTER TABLE user_investments ADD CONSTRAINT user_investments_transaction_id_fkey
  FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL;

ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS subscriptions_payment_transaction_id_fkey;
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_payment_transaction_id_fkey
  FOREIGN KEY (payment_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL;

-- ============================================
-- PHASE 3: Fix auth.users-level FK blockers
-- ============================================

ALTER TABLE ads DROP CONSTRAINT IF EXISTS ads_created_by_fkey;
ALTER TABLE ads ADD CONSTRAINT ads_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE agent_applications DROP CONSTRAINT IF EXISTS agent_applications_reviewed_by_fkey;
ALTER TABLE agent_applications ADD CONSTRAINT agent_applications_reviewed_by_fkey
  FOREIGN KEY (reviewed_by) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE audit_logs DROP CONSTRAINT IF EXISTS audit_logs_admin_id_fkey;
ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_admin_id_fkey
  FOREIGN KEY (admin_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- ============================================
-- PHASE 4: Create fn_admin_hard_delete_user
-- Comprehensive RPC callable from admin session
-- ============================================
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

  -- Phase 1: NULL cross-references
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

  -- Phase 2: Break circular dependencies
  UPDATE user_investments SET locked_by_loan_id = NULL, transaction_id = NULL
    WHERE user_id = p_user_id;
  UPDATE loans SET collateral_investment_id = NULL WHERE user_id = p_user_id;
  UPDATE subscriptions SET payment_transaction_id = NULL WHERE user_id = p_user_id;

  -- Phase 3: Explicit deletion
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
  DELETE FROM recurring_investments WHERE user_id = p_user_id;
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

  -- Phase 4: Delete profile
  DELETE FROM profiles WHERE id = p_user_id;

  -- Phase 5: Delete auth user
  DELETE FROM auth.users WHERE id = p_user_id;

  -- Phase 6: Audit
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
