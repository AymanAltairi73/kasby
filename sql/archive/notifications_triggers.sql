-- ==========================================
-- 🔔 1. Chat Notifications Trigger
-- ==========================================

CREATE OR REPLACE FUNCTION public.trigger_chat_notification()
RETURNS trigger AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_sender_name TEXT;
    v_target_user_id UUID;
    v_project_url TEXT := 'https://majnuiypsgosbzsaeefc.supabase.co'; -- Updated project URL
BEGIN
    -- Get sender name
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = auth.uid();
    IF v_sender_name IS NULL THEN v_sender_name := 'User'; END IF;

    -- Determine recipient
    IF NEW.sender_type = 'user' THEN
        -- Notify Admin (Support)
        -- For now, we notify the assigned_admin_id if present, 
        -- otherwise we might need a general way to notify all admins.
        -- Let's assume we notify the assigned_admin_id.
        SELECT assigned_admin_id INTO v_target_user_id 
        FROM public.chat_conversations 
        WHERE id = NEW.conversation_id;
        
        -- If no assigned admin yet, we might want to notify all admins, 
        -- but for this snippet we'll target the assigned one.
        IF v_target_user_id IS NOT NULL THEN
            SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = v_target_user_id;
        END IF;
    ELSE
        -- Notify User
        SELECT user_id INTO v_target_user_id 
        FROM public.chat_conversations 
        WHERE id = NEW.conversation_id;
        
        IF v_target_user_id IS NOT NULL THEN
            SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = v_target_user_id;
        END IF;
    END IF;

    -- Send FCM if token exists
    IF v_recipient_fcm_token IS NOT NULL THEN
        BEGIN
            PERFORM net.http_post(
                url := v_project_url || '/functions/v1/send-fcm',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || COALESCE(
                        (NULLIF(current_setting('request.headers', true), '')::jsonb)->>'authorization',
                        'internal_service_role' 
                    )
                ),
                body := jsonb_build_object(
                    'token', v_recipient_fcm_token,
                    'title', 'رسالة جديدة من ' || v_sender_name,
                    'body', NEW.content,
                    'data', jsonb_build_object(
                        'type', 'chat',
                        'conversation_id', NEW.conversation_id
                    )
                )
            );
        EXCEPTION WHEN OTHERS THEN
            -- Isolation: Prevent notification failure from breaking the chat transaction
            RAISE WARNING 'Chat notification failed: %', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_chat_message_inserted ON public.chat_messages;
CREATE TRIGGER on_chat_message_inserted
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_chat_notification();


-- ==========================================
-- 💰 2. Reward Notifications Trigger
-- ==========================================

CREATE OR REPLACE FUNCTION public.trigger_reward_notification()
RETURNS trigger AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_project_url TEXT := 'https://majnuiypsgosbzsaeefc.supabase.co';
BEGIN
    -- Only active for COMPLETED rewards or profits
    IF (NEW.type = 'reward' OR NEW.type = 'profit') AND NEW.status = 'completed' THEN
        SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = NEW.user_id;

        IF v_recipient_fcm_token IS NOT NULL THEN
            BEGIN
                PERFORM net.http_post(
                    url := v_project_url || '/functions/v1/send-fcm',
                    headers := jsonb_build_object(
                        'Content-Type', 'application/json',
                        'Authorization', 'Bearer ' || COALESCE(
                            (NULLIF(current_setting('request.headers', true), '')::jsonb)->>'authorization',
                            'internal_service_role'
                        )
                    ),
                    body := jsonb_build_object(
                        'token', v_recipient_fcm_token,
                        'title', 'أرباحك اليومية وصلت ✅',
                        'body', 'تم إضافة ' || NEW.amount || ' إلى حسابك بنجاح.',
                        'data', jsonb_build_object(
                            'type', 'reward',
                            'transaction_id', NEW.id
                        )
                    )
                );
            EXCEPTION WHEN OTHERS THEN
                -- Isolation: Prevent notification failure from breaking the reward transaction
                RAISE WARNING 'Reward notification failed: %', SQLERRM;
            END;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_reward_transaction_inserted ON public.transactions;
CREATE TRIGGER on_reward_transaction_inserted
    AFTER INSERT ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_reward_notification();


-- ==========================================
-- 🔔 3. Generic Notifications Trigger
-- ==========================================
-- This fires whenever a record is added to the 'notifications' table,
-- ensuring that manual admin alerts and automated profits send a push.

CREATE OR REPLACE FUNCTION public.trigger_generic_notification()
RETURNS trigger AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_project_url TEXT := 'https://majnuiypsgosbzsaeefc.supabase.co';
BEGIN
    -- Get recipient FCM token
    SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = NEW.user_id;

    IF v_recipient_fcm_token IS NOT NULL THEN
        BEGIN
            PERFORM net.http_post(
                url := v_project_url || '/functions/v1/send-fcm',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || COALESCE(
                        (NULLIF(current_setting('request.headers', true), '')::jsonb)->>'authorization',
                        'internal_service_role'
                    )
                ),
                body := jsonb_build_object(
                    'token', v_recipient_fcm_token,
                    'title', NEW.title,
                    'body', NEW.message,
                    'data', jsonb_build_object(
                        'type', 'notification',
                        'id', NEW.id
                    )
                )
            );
        EXCEPTION WHEN OTHERS THEN
            -- Isolation: Prevent notification failure from breaking the generic notification transaction
            RAISE WARNING 'Generic notification failed: %', SQLERRM;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_notification_inserted ON public.notifications;
CREATE TRIGGER on_notification_inserted
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_generic_notification();
