-- SQL migration to add referral_commission notification type

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (
    type IS NULL OR type = ANY (ARRAY[
      -- Financial
      'deposit_submitted',
      'deposit_approved',
      'deposit_rejected',
      'withdrawal_requested',
      'withdrawal_approved',
      'withdrawal_rejected',
      'withdrawal_completed',
      'transfer_received',
      'transfer_sent',
      -- Loans
      'loan_requested',
      'loan_approved',
      'loan_rejected',
      'loan_repayment_due',
      'loan_overdue',
      'loan_paid',
      -- Investments
      'investment_created',
      'daily_profit',
      'investment_matured',
      'investment_cancelled',
      -- Chat
      'chat_new_message',
      'chat_admin_reply',
      'chat_resolved',
      'chat_escalated',
      -- KYC & account
      'kyc_approved',
      'kyc_rejected',
      'account_flagged',
      'account_frozen',
      'account_blocked',
      'account_reactivated',
      'account_deleted',
      'account_unblocked',
      'permission_withdrawal_granted',
      'permission_transfer_granted',
      'permission_qr_receive_granted',
      'role_upgraded',
      'profile_updated',
      'commission_earned',
      -- Referral & agent
      'referral_bonus',
      'referral_commission',
      'agent_deposit_pending',
      'agent_withdrawal_pending',
      'agent_role_change',
      -- Admin
      'admin_kyc_pending',
      'admin_withdrawal_pending',
      'admin_deposit_pending',
      'admin_flagged_user',
      'admin_new_chat',
      'admin_user_deleted',
      -- Social
      'social_friend_request',
      'social_friend_accepted',
      'social_chat',
      -- System / generic
      'system',
      'maintenance',
      'announcement',
      'security_alert',
      'info',
      'success',
      'warning',
      'critical',
      'reward',
      'notification',
      'wheel_reminder',
      'checkin_reminder'
    ]::TEXT[])
  );

-- Recreate resolve_notification_route with referral_commission support
CREATE OR REPLACE FUNCTION public.resolve_notification_route(
    p_type TEXT,
    p_deep_link TEXT DEFAULT NULL,
    p_entity_type TEXT DEFAULT NULL,
    p_role_target TEXT DEFAULT 'user'
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_deep_link IS NOT NULL AND TRIM(p_deep_link) != '' THEN
        RETURN TRIM(p_deep_link);
    END IF;

    IF p_role_target = 'admin' THEN
        IF p_type IN (
            'admin_kyc_pending', 'kyc_approved', 'kyc_rejected'
        ) THEN RETURN '/kyc';
        ELSIF p_type IN (
            'admin_withdrawal_pending', 'withdrawal_requested', 'withdrawal_approved',
            'withdrawal_rejected', 'withdrawal_completed'
        ) THEN RETURN '/transactions';
        ELSIF p_type IN (
            'admin_deposit_pending', 'deposit_submitted', 'deposit_approved', 'deposit_rejected'
        ) THEN RETURN '/transactions';
        ELSIF p_type IN (
            'admin_new_chat', 'chat_new_message', 'chat_admin_reply', 'chat_escalated'
        ) THEN RETURN '/chat-list';
        ELSIF p_type IN (
            'loan_requested', 'loan_approved', 'loan_rejected',
            'loan_repayment_due', 'loan_overdue', 'loan_paid'
        ) THEN RETURN '/loans';
        ELSIF p_type IN (
            'investment_created', 'investment_matured', 'investment_cancelled'
        ) THEN RETURN '/user-investments';
        ELSIF p_type IN ('admin_flagged_user', 'admin_user_deleted') THEN RETURN '/users';
        ELSIF p_type IN (
            'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change'
        ) THEN RETURN '/agents';
        ELSE RETURN '/notifications-list';
        END IF;
    END IF;

    IF p_type IN ('deposit_submitted', 'deposit_approved', 'deposit_rejected') THEN
        RETURN '/deposit';
    ELSIF p_type IN (
        'withdrawal_requested', 'withdrawal_approved', 'withdrawal_rejected', 'withdrawal_completed',
        'permission_withdrawal_granted'
    ) THEN
        RETURN '/withdraw';
    ELSIF p_type IN ('transfer_received', 'transfer_sent', 'permission_transfer_granted') THEN
        RETURN '/wallet';
    ELSIF p_type = 'permission_qr_receive_granted' THEN
        RETURN '/my-qr';
    ELSIF p_type IN (
        'loan_requested', 'loan_approved', 'loan_rejected',
        'loan_repayment_due', 'loan_overdue', 'loan_paid'
    ) THEN
        RETURN '/loan';
    ELSIF p_type IN (
        'investment_created', 'daily_profit', 'investment_matured', 'investment_cancelled'
    ) THEN
        RETURN '/my-investments';
    ELSIF p_type IN ('referral_bonus', 'referral_commission', 'reward') THEN
        RETURN '/my-team';
    ELSIF p_type IN (
        'kyc_approved', 'kyc_rejected', 'account_flagged', 'account_frozen', 'role_upgraded'
    ) THEN
        RETURN '/kyc';
    ELSIF p_type IN ('account_blocked') THEN
        RETURN '/support';
    ELSIF p_type IN ('account_reactivated') THEN
        RETURN '/home';
    ELSIF p_type IN ('social_friend_request', 'social_friend_accepted') THEN
        RETURN '/friend-requests';
    ELSIF p_type = 'social_chat' THEN
        RETURN '/social-chat';
    ELSIF p_type IN (
        'chat_admin_reply', 'chat_new_message', 'chat_resolved', 'chat_escalated'
    ) THEN
        RETURN '/support-chat';
    ELSIF p_type IN (
        'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change'
    ) THEN
        RETURN '/agent-dashboard';
    ELSIF p_type IN (
        'announcement', 'maintenance', 'security_alert', 'system',
        'info', 'warning', 'notification'
    ) THEN
        RETURN '/notifications';
    ELSIF p_entity_type = 'transaction' THEN
        RETURN '/transaction-details';
    ELSIF p_entity_type = 'conversation' THEN
        RETURN '/support-chat';
    ELSE
        RETURN '/notifications';
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_notification_route(TEXT, TEXT, TEXT, TEXT)
  TO authenticated, anon, service_role;
