-- ============================================================================
-- KASBY: Smart Notification Navigation — FCM payload enrichment
-- Date: 2026-06-11
-- Forwards deep_link, entity_type, entity_id, target_user_id in FCM data
-- so mobile clients can route on tap (foreground, background, cold-start).
-- ============================================================================

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
        ELSIF p_type = 'admin_flagged_user' THEN RETURN '/users';
        ELSIF p_type IN (
            'agent_deposit_pending', 'agent_withdrawal_pending', 'agent_role_change'
        ) THEN RETURN '/agents';
        ELSE RETURN '/notifications-list';
        END IF;
    END IF;

    IF p_type IN ('deposit_submitted', 'deposit_approved', 'deposit_rejected') THEN
        RETURN '/deposit';
    ELSIF p_type IN (
        'withdrawal_requested', 'withdrawal_approved', 'withdrawal_rejected', 'withdrawal_completed'
    ) THEN
        RETURN '/withdraw';
    ELSIF p_type IN ('transfer_received', 'transfer_sent') THEN
        RETURN '/wallet';
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

CREATE OR REPLACE FUNCTION public.trigger_generic_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_project_url TEXT := 'https://majnuiypsgosbzsaeefc.supabase.co';
    v_fcm_secret TEXT;
    v_route TEXT;
BEGIN
    SELECT fcm_token INTO v_recipient_fcm_token
    FROM public.profiles
    WHERE id = NEW.user_id;

    IF v_recipient_fcm_token IS NOT NULL THEN
        v_fcm_secret := private.get_key('fcm_secret');
        v_route := public.resolve_notification_route(
            NEW.type,
            NEW.deep_link,
            NEW.entity_type,
            COALESCE(NEW.role_target, 'user')
        );

        BEGIN
            PERFORM net.http_post(
                url := v_project_url || '/functions/v1/send-fcm',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_fcm_secret
                ),
                body := jsonb_build_object(
                    'token', v_recipient_fcm_token,
                    'title', NEW.title,
                    'body', NEW.message,
                    'data', jsonb_build_object(
                        'type', COALESCE(NEW.type, 'notification'),
                        'id', NEW.id::TEXT,
                        'route', v_route,
                        'entity_type', COALESCE(NEW.entity_type, ''),
                        'entity_id', COALESCE(NEW.entity_id, ''),
                        'target_user_id', COALESCE(NEW.target_user_id::TEXT, ''),
                        'deep_link', COALESCE(NEW.deep_link, ''),
                        'role_target', COALESCE(NEW.role_target, 'user')
                    )
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Generic notification failed: %', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_notification_inserted ON public.notifications;
CREATE TRIGGER on_notification_inserted
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_generic_notification();

GRANT EXECUTE ON FUNCTION public.resolve_notification_route(TEXT, TEXT, TEXT, TEXT) TO authenticated, anon, service_role;
