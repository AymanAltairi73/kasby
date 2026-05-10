-- ============================================================
-- FCM Push Notifications Setup
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Add FCM Token column to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;

-- 2. RPC to update FCM token from Flutter App
CREATE OR REPLACE FUNCTION public.update_fcm_token(p_token TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    
    UPDATE public.profiles
    SET fcm_token = p_token
    WHERE id = auth.uid();
END;
$$;

-- 3. Webhook Trigger Function for Notifications
-- Note: You should specify your Edge Function URL here once deployed.
-- Example: 'https://majnuiypsgosbzsaeefc.supabase.co/functions/v1/send-fcm'
CREATE OR REPLACE FUNCTION public.trigger_fcm_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_fcm_token TEXT;
    v_url TEXT := 'https://majnuiypsgosbzsaeefc.supabase.co/functions/v1/send-fcm';
    v_bearer TEXT := current_setting('request.jwt.claim.sub', true); -- Optional if we need auth
    v_payload JSONB;
BEGIN
    -- Scenario 1: New Transaction (Points/Rewards added)
    IF TG_TABLE_NAME = 'transactions' AND TG_OP = 'INSERT' THEN
        -- Only notify if it's a deposit or reward
        IF NEW.type IN ('reward', 'deposit', 'referral_bonus') AND NEW.status = 'completed' THEN
            -- Get FCM token
            SELECT fcm_token INTO v_fcm_token FROM profiles WHERE id = NEW.user_id;
            
            IF v_fcm_token IS NOT NULL THEN
                v_payload := jsonb_build_object(
                    'token', v_fcm_token,
                    'title', 'أضافات مالية جديدة! 💰',
                    'body', 'تم إضافة ' || NEW.amount || ' إلى رصيدك. تحقق من محفظتك الآن!',
                    'data', jsonb_build_object('route', '/wallet', 'id', NEW.id)
                );
                
                PERFORM net.http_post(
                    url := v_url,
                    headers := '{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('request.headers', true)::json->>'authorization' || '"}',
                    body := v_payload
                );
            END IF;
        END IF;
    END IF;

    -- Scenario 2: Friend Request accepted or new Referral
    -- (This is a simplified template, you can customize it further)

    RETURN NEW;
END;
$$;

-- Create Trigger on transactions table
DROP TRIGGER IF EXISTS trigger_transaction_notification ON public.transactions;
CREATE TRIGGER trigger_transaction_notification
    AFTER INSERT ON public.transactions
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_fcm_notification();
