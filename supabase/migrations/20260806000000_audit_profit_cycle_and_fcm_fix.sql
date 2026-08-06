-- ============================================================
-- Migration: End-to-End Profit Cycle & FCM Token Architecture Fix
-- Date: 2026-08-06
-- Description:
--   1. Fix FCM Token Sync & Fallback (trigger_generic_notification + fn_register_device_token + fn_clear_device_token).
--   2. Strict Subscribed (Auto) vs Non-Subscribed (Manual) Profit Cycles in fn_cron_distribute_daily_profits.
--   3. Dynamic Profit Notification Details with amount, currency, plan name, entity_id, and deep_link.
--   4. Allow fn_start_next_cycle for manual cycle activation when cycle completed.
--   5. Schedule backend pg_cron job for automated server execution.
-- ============================================================

-- 1. Device Token Management RPCs
CREATE OR REPLACE FUNCTION "public"."fn_register_device_token"(
    "p_token" "text", 
    "p_platform" "text" DEFAULT 'android'::"text", 
    "p_app_type" "text" DEFAULT 'user'::"text"
) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    IF p_token IS NULL OR LENGTH(TRIM(p_token)) < 10 THEN
        RETURN;
    END IF;

    -- A. Disassociate token from any other profiles to ensure strict single-user token ownership
    UPDATE public.profiles 
    SET fcm_token = NULL 
    WHERE fcm_token = p_token AND id != v_user_id;

    -- B. Deactivate token in device_tokens if previously assigned to another user
    UPDATE public.device_tokens 
    SET is_active = FALSE, updated_at = NOW()
    WHERE token = p_token AND user_id != v_user_id;

    -- C. Upsert device token for current user
    INSERT INTO public.device_tokens (user_id, token, platform, app_type, is_active, updated_at)
    VALUES (v_user_id, p_token, p_platform, p_app_type, TRUE, NOW())
    ON CONFLICT (token) DO UPDATE
    SET user_id = v_user_id,
        platform = p_platform,
        app_type = p_app_type,
        is_active = TRUE,
        updated_at = NOW();

    -- D. Update legacy profiles.fcm_token
    UPDATE public.profiles 
    SET fcm_token = p_token 
    WHERE id = v_user_id;
END;
$$;

ALTER FUNCTION "public"."fn_register_device_token"("p_token" "text", "p_platform" "text", "p_app_type" "text") OWNER TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."fn_register_device_token"("p_token" "text", "p_platform" "text", "p_app_type" "text") TO "authenticated";


-- RPC to clear token on logout
CREATE OR REPLACE FUNCTION "public"."fn_clear_device_token"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE public.device_tokens
    SET is_active = FALSE, updated_at = NOW()
    WHERE user_id = v_user_id;

    UPDATE public.profiles
    SET fcm_token = NULL
    WHERE id = v_user_id;
END;
$$;

ALTER FUNCTION "public"."fn_clear_device_token"() OWNER TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."fn_clear_device_token"() TO "authenticated";


-- 2. Enhanced trigger_generic_notification with fallback token lookup
CREATE OR REPLACE FUNCTION "public"."trigger_generic_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_project_url TEXT := 'https://majnuiypsgosbzsaeefc.supabase.co';
    v_service_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5-d142E70b_5aFhVlX8k9Y7zX9b8c7d6e5f4a3b2c1';
    v_fcm_secret TEXT := 'kasby_internal_fcm_secret_2026_x972f';
    v_auth_token TEXT;
BEGIN
    -- 1. Try profiles.fcm_token
    SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = NEW.user_id;

    -- 2. Fallback to active token in device_tokens if profile token is empty
    IF v_recipient_fcm_token IS NULL OR LENGTH(TRIM(v_recipient_fcm_token)) < 10 THEN
        SELECT token INTO v_recipient_fcm_token
        FROM public.device_tokens
        WHERE user_id = NEW.user_id AND is_active = TRUE
        ORDER BY updated_at DESC LIMIT 1;
    END IF;
    
    IF v_recipient_fcm_token IS NOT NULL AND LENGTH(TRIM(v_recipient_fcm_token)) > 10 THEN
        v_auth_token := COALESCE(v_fcm_secret, v_service_key);
        
        BEGIN
            PERFORM net.http_post(
                url := v_project_url || '/functions/v1/send-fcm',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_auth_token
                ),
                body := jsonb_build_object(
                    'token', v_recipient_fcm_token,
                    'title', COALESCE(NEW.title, 'Kasby Notification'),
                    'body', COALESCE(NEW.message, ''),
                    'data', jsonb_build_object(
                        'id', NEW.id::TEXT,
                        'type', COALESCE(NEW.type, 'notification'),
                        'entity_type', COALESCE(NEW.entity_type, ''),
                        'entity_id', COALESCE(NEW.entity_id, ''),
                        'route', COALESCE(NEW.deep_link, '/my-investments'),
                        'deep_link', COALESCE(NEW.deep_link, '/my-investments'),
                        'role_target', COALESCE(NEW.role_target, 'user')
                    )
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Generic notification FCM trigger failed: %', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."trigger_generic_notification"() OWNER TO "postgres";

DROP TRIGGER IF EXISTS "on_notification_inserted" ON "public"."notifications";
CREATE TRIGGER "on_notification_inserted" 
    AFTER INSERT ON "public"."notifications" 
    FOR EACH ROW 
    EXECUTE FUNCTION "public"."trigger_generic_notification"();


-- 3. fn_start_next_cycle allowing manual activation when cycle completed
CREATE OR REPLACE FUNCTION "public"."fn_start_next_cycle"("p_investment_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_inv RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT * INTO v_inv
    FROM user_investments
    WHERE id = p_investment_id AND user_id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Investment not found');
    END IF;

    IF v_inv.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Investment is not active');
    END IF;

    -- If cycle is currently active in the future, reject
    IF v_inv.next_payout_at IS NOT NULL AND v_inv.next_payout_at > NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cycle is already running');
    END IF;

    -- Start 24h cycle
    UPDATE user_investments
    SET next_payout_at = NOW() + INTERVAL '24 hours'
    WHERE id = p_investment_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

ALTER FUNCTION "public"."fn_start_next_cycle"("p_investment_id" "uuid") OWNER TO "postgres";
GRANT EXECUTE ON FUNCTION "public"."fn_start_next_cycle"("p_investment_id" "uuid") TO "authenticated";


-- 4. Server-Authoritative Profit Distribution Function
CREATE OR REPLACE FUNCTION "public"."fn_cron_distribute_daily_profits"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_inv RECORD;
    v_profit NUMERIC(18,4);
    v_profit_formatted TEXT;
    v_wallet_id UUID;
    v_plan_name_ar TEXT;
    v_already_notified BOOLEAN;
    v_has_active_sub BOOLEAN;
    v_should_auto_restart BOOLEAN;
BEGIN
    -- Pause guard
    IF EXISTS (SELECT 1 FROM public.system_settings WHERE pause_profits = TRUE LIMIT 1) THEN
        RETURN;
    END IF;

    FOR v_inv IN
        SELECT 
            ui.id, 
            ui.user_id, 
            ui.plan_id,
            ui.amount, 
            ui.profit_percentage, 
            ui.end_date,
            ui.last_profit_at, 
            ui.is_collateral_locked, 
            ui.next_payout_at, 
            ui.auto_restart_enabled,
            COALESCE(ip.name_ar, ip.name_en, 'خطة الاستثمار') AS plan_name_ar
        FROM public.user_investments ui
        LEFT JOIN public.investment_plans ip ON ip.id = ui.plan_id
        WHERE ui.status = 'active'
          AND ui.next_payout_at IS NOT NULL
          AND NOW() >= ui.next_payout_at
        FOR UPDATE OF ui SKIP LOCKED
    LOOP
        -- Calculate daily profit amount
        v_profit := ROUND((v_inv.amount * (v_inv.profit_percentage / 100) / 365), 4);

        IF v_profit > 0 THEN
            SELECT id INTO v_wallet_id
            FROM public.wallets WHERE user_id = v_inv.user_id
            FOR UPDATE;

            IF v_wallet_id IS NOT NULL THEN
                -- A. Credit wallet balances
                UPDATE public.wallets
                SET available_balance = available_balance + v_profit,
                    profit_balance = profit_balance + v_profit,
                    updated_at = NOW()
                WHERE id = v_wallet_id;

                -- B. Record profit transaction
                INSERT INTO public.transactions (
                    user_id, wallet_id, type, amount, status, description, running_balance
                ) VALUES (
                    v_inv.user_id, v_wallet_id, 'profit', v_profit, 'completed',
                    'أرباح يومية — ' || v_inv.plan_name_ar,
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id)
                );

                -- C. Clean format profit string
                v_profit_formatted := CASE 
                    WHEN v_profit = FLOOR(v_profit) THEN (v_profit::BIGINT)::TEXT
                    WHEN v_profit = ROUND(v_profit, 2) THEN TO_CHAR(v_profit, 'FM999999990.00')
                    ELSE RTRIM(RTRIM(TO_CHAR(v_profit, 'FM999999990.0000'), '0'), '.')
                END;

                -- D. Deduplication Guard: 1 Payout = 1 Notification (23h window)
                SELECT EXISTS (
                    SELECT 1 FROM public.notifications
                    WHERE user_id = v_inv.user_id
                      AND type = 'daily_profit'
                      AND entity_id = v_inv.id::TEXT
                      AND created_at >= NOW() - INTERVAL '23 hours'
                ) INTO v_already_notified;

                -- E. Create structured dynamic profit notification
                IF NOT v_already_notified THEN
                    PERFORM public.fn_create_notification(
                        v_inv.user_id,
                        'أرباح استثمار جديدة 💰',
                        'تم إضافة أرباح بقيمة $' || v_profit_formatted || ' من ' || v_inv.plan_name_ar,
                        'daily_profit',
                        'investment',
                        v_inv.id::TEXT,
                        '/my-investments',
                        'user',
                        'normal'
                    );
                END IF;
            END IF;
        END IF;

        -- Check Subscription Status dynamically from Backend
        SELECT EXISTS (
            SELECT 1 FROM public.subscriptions 
            WHERE user_id = v_inv.user_id 
              AND status = 'active' 
              AND (expires_at IS NULL OR expires_at > NOW())
        ) OR EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = v_inv.user_id AND account_tier IN ('premium', 'vip')
        ) INTO v_has_active_sub;

        v_should_auto_restart := v_has_active_sub AND v_inv.auto_restart_enabled;

        -- Update investment cycle state
        IF v_should_auto_restart THEN
            -- SUBSCRIBED USER: Start next 24-hour cycle automatically
            UPDATE public.user_investments
            SET last_profit_at = NOW(),
                actual_profit = COALESCE(actual_profit, 0) + v_profit,
                next_payout_at = GREATEST(NOW(), v_inv.next_payout_at) + INTERVAL '24 hours'
            WHERE id = v_inv.id;
        ELSE
            -- NON-SUBSCRIBED USER or EXPIRED SUB: Cycle completed, wait for manual activation
            UPDATE public.user_investments
            SET last_profit_at = NOW(),
                actual_profit = COALESCE(actual_profit, 0) + v_profit,
                next_payout_at = NULL,
                auto_restart_enabled = FALSE
            WHERE id = v_inv.id;
        END IF;

        -- Maturity check (collateral lock aware)
        IF v_inv.end_date IS NOT NULL AND v_inv.end_date <= NOW() THEN
            IF v_inv.is_collateral_locked THEN
                INSERT INTO public.system_logs (
                    actor_id, actor_role, action, entity_type, entity_id, details, severity
                ) VALUES (
                    NULL, 'system', 'maturity_held_by_collateral', 'investment', v_inv.id::TEXT,
                    jsonb_build_object(
                        'reason', 'Investment matured but locked as collateral',
                        'user_id', v_inv.user_id,
                        'amount', v_inv.amount
                    ), 'warning'
                );
                CONTINUE;
            END IF;

            UPDATE public.user_investments
            SET status = 'matured', matured_at = NOW(), next_payout_at = NULL
            WHERE id = v_inv.id;

            IF v_wallet_id IS NULL THEN
                SELECT id INTO v_wallet_id
                FROM public.wallets WHERE user_id = v_inv.user_id FOR UPDATE;
            END IF;

            IF v_wallet_id IS NOT NULL THEN
                UPDATE public.wallets
                SET available_balance = available_balance + v_inv.amount,
                    invested_balance = invested_balance - v_inv.amount,
                    updated_at = NOW()
                WHERE id = v_wallet_id;

                INSERT INTO public.transactions (
                    user_id, wallet_id, type, amount, status, description, running_balance
                ) VALUES (
                    v_inv.user_id, v_wallet_id, 'investment_return', v_inv.amount, 'completed',
                    'اكتمال الاستثمار — استعادة رأس المال',
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id)
                );

                PERFORM public.fn_create_notification(
                    v_inv.user_id,
                    'اكتمل الاستثمار 🎉',
                    'اكتملت مدة استثمارك في ' || v_inv.plan_name_ar || ' وتم إرجاع رأس المال بمبلغ $' || (v_inv.amount::BIGINT)::TEXT || ' إلى محفظتك.',
                    'investment_matured',
                    'investment',
                    v_inv.id::TEXT,
                    '/my-investments',
                    'user',
                    'high'
                );
            END IF;
        END IF;

    END LOOP;
END;
$$;

ALTER FUNCTION "public"."fn_cron_distribute_daily_profits"() OWNER TO "postgres";


-- 5. Enable pg_cron Extension and Schedule Automated Backend Cron Job
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Clear previous schedule if present
SELECT cron.unschedule('distribute-daily-profits-job')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'distribute-daily-profits-job');

-- Schedule server-side profit distribution to execute every 1 minute
SELECT cron.schedule(
    'distribute-daily-profits-job',
    '* * * * *',
    $$SELECT public.fn_cron_distribute_daily_profits()$$
);
