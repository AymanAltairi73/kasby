-- ============================================================================
-- AGENT CHAT MESSAGE DELIVERY FIX
-- Root Cause: Missing notification type and trigger for agent chat messages
-- ============================================================================
-- Problem Analysis:
-- 1. Notification type 'agent_chat_new_message' does not exist in CHECK constraint
-- 2. Function fn_trigger_chat_push_notification() exists but is NOT triggered on chat_messages
-- 3. Agent chat category is not handled in notification creation logic
-- 4. Messages succeed but notifications fail or are never created
-- ============================================================================

-- 0. Normalize existing notification types to prevent CHECK constraint violation
-- This handles any legacy or invalid notification types in existing data
UPDATE public.notifications 
SET type = 'system' 
WHERE type IS NOT NULL 
  AND type NOT IN (
    'deposit_submitted', 'deposit_approved', 'deposit_rejected',
    'withdrawal_requested', 'withdrawal_approved', 'withdrawal_rejected', 'withdrawal_completed',
    'transfer_received', 'transfer_sent',
    'loan_requested', 'loan_approved', 'loan_rejected', 'loan_repayment_due', 'loan_overdue', 'loan_paid',
    'investment_created', 'daily_profit', 'investment_matured', 'investment_cancelled',
    'chat_new_message', 'chat_admin_reply', 'chat_resolved', 'chat_escalated',
    'kyc_approved', 'kyc_rejected', 'account_flagged', 'account_frozen', 'account_blocked',
    'account_reactivated', 'account_deleted', 'account_unblocked',
    'permission_withdrawal_granted', 'permission_transfer_granted', 'permission_qr_receive_granted',
    'role_upgraded', 'profile_updated', 'commission_earned',
    'referral_bonus', 'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change',
    'admin_kyc_pending', 'admin_withdrawal_pending', 'admin_deposit_pending', 'admin_flagged_user',
    'admin_new_chat', 'admin_user_deleted',
    'social_friend_request', 'social_friend_accepted', 'social_chat',
    'system', 'maintenance', 'announcement', 'security_alert', 'info', 'success', 'warning', 'critical',
    'reward', 'notification', 'wheel_reminder', 'checkin_reminder'
  );

-- 1. Add agent_chat_new_message to notifications CHECK constraint
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
      'agent_chat_new_message',  -- NEW: Agent chat notification type
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

-- 2. Update notification route resolver to handle agent_chat_new_message
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
            'admin_new_chat', 'chat_new_message', 'chat_admin_reply', 'chat_escalated', 'agent_chat_new_message'
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
    ELSIF p_type IN ('referral_bonus', 'reward') THEN
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
    ELSIF p_type = 'agent_chat_new_message' THEN
        RETURN '/support-chat';
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

-- 3. Update chat notification trigger to handle agent chat category
CREATE OR REPLACE FUNCTION public.fn_trigger_chat_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
    v_target_user_id UUID;
    v_sender_name TEXT;
    v_type TEXT;
    v_deep_link TEXT;
    v_msg_text TEXT;
    v_conv_category TEXT;
    v_conv_is_agent_chat BOOLEAN;
    v_conv_agent_id UUID;
BEGIN
    -- Skip system messages for push
    IF NEW.sender_type = 'system' THEN RETURN NEW; END IF;

    -- Get conversation details
    SELECT category, is_agent_chat, agent_id
    INTO v_conv_category, v_conv_is_agent_chat, v_conv_agent_id
    FROM public.chat_conversations WHERE id = NEW.conversation_id;

    -- Skip social chats since they are already notified to peers via handle_chat_message_logic()
    IF v_conv_category = 'social' THEN RETURN NEW; END IF;

    -- Use message_content ONLY
    v_msg_text := NEW.message_content;

    -- Get sender name
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = NEW.sender_id;
    IF v_sender_name IS NULL THEN v_sender_name := 'كاسبي'; END IF;

    -- Handle agent chat notifications
    IF COALESCE(v_conv_is_agent_chat, false) THEN
        IF NEW.sender_type = 'agent' THEN
            -- Agent sent → notify user
            SELECT user_id INTO v_target_user_id
            FROM public.chat_conversations WHERE id = NEW.conversation_id;
            v_type := 'agent_chat_new_message';
            v_deep_link := '/support-chat';
        ELSIF NEW.sender_type = 'user' THEN
            -- User sent → notify agent
            SELECT a.user_id INTO v_target_user_id
            FROM public.agents a
            WHERE a.id = v_conv_agent_id;
            v_type := 'chat_new_message';
            v_deep_link := '/support-chat';
        ELSE
            RETURN NEW;
        END IF;
    ELSIF NEW.sender_type = 'admin' THEN
        -- Admin sent → notify user
        SELECT user_id INTO v_target_user_id
        FROM public.chat_conversations WHERE id = NEW.conversation_id;
        v_type := 'chat_admin_reply';
        v_deep_link := '/support-chat';
    ELSIF NEW.sender_type IN ('user', 'agent') THEN
        -- User/Agent sent → notify assigned admin (or all admins)
        SELECT assigned_admin_id INTO v_target_user_id
        FROM public.chat_conversations WHERE id = NEW.conversation_id;

        -- If no assigned admin, notify all admins
        IF v_target_user_id IS NULL THEN
            DECLARE
                v_admin_ids UUID[];
            BEGIN
                SELECT ARRAY_AGG(id) INTO v_admin_ids
                FROM public.admin_profiles WHERE is_active = TRUE;

                IF v_admin_ids IS NOT NULL THEN
                    PERFORM public.fn_create_bulk_notification(
                        v_admin_ids,
                        'رسالة دعم جديدة من ' || v_sender_name,
                        CASE WHEN NEW.message_type = 'image' THEN '📷 صورة'
                             ELSE LEFT(v_msg_text, 80) END,
                        'admin_new_chat', 'conversation', NEW.conversation_id::TEXT,
                        '/chat', 'admin'
                    );
                END IF;
                RETURN NEW;
            END;
        END IF;

        v_type := 'chat_new_message';
        v_deep_link := '/chat';
    ELSE
        RETURN NEW;
    END IF;

    -- Create notification for target user
    IF v_target_user_id IS NOT NULL THEN
        BEGIN
            PERFORM public.fn_create_notification(
                v_target_user_id,
                'رسالة جديدة من ' || v_sender_name,
                CASE WHEN NEW.message_type = 'image' THEN '📷 صورة'
                     ELSE LEFT(v_msg_text, 80) END,
                v_type, 'conversation', NEW.conversation_id::TEXT, v_deep_link
            );
        EXCEPTION WHEN OTHERS THEN
            -- Notification failure should NOT block message delivery
            RAISE WARNING 'Failed to create chat notification for conversation %: %', NEW.conversation_id, SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$;

-- 4. Attach the notification trigger to chat_messages table
DROP TRIGGER IF EXISTS trg_chat_message_notification ON public.chat_messages;
CREATE TRIGGER trg_chat_message_notification
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_trigger_chat_push_notification();

-- 5. Ensure grants
GRANT EXECUTE ON FUNCTION public.resolve_notification_route(TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, service_role;
