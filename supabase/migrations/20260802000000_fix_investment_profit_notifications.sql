-- ============================================================
-- Migration: Fix Investment Profit Notification Flow & Triggers
-- Date: 2026-08-02
-- Description:
--   1. Fix fn_cron_distribute_daily_profits to fetch plan name, format profit,
--      prevent duplicate notifications, and create structured profit notifications.
--   2. Update trigger_generic_notification to pass exact notification type,
--      entity metadata, and route to send-fcm.
--   3. Streamline fn_create_notification to avoid duplicate push calls.
-- ============================================================

-- 1. Redefine trigger_generic_notification to construct complete FCM payloads
CREATE OR REPLACE FUNCTION "public"."trigger_generic_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_project_url TEXT := 'https://majnuiypsgosbzsaeefc.supabase.co';
    -- Use service role / system secret to authorize against send-fcm Edge Function
    v_service_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ham51aXlwc2dvc2J6c2FlZWZjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjA3MDk3NSwiZXhwIjoyMDg3NjQ2OTc1fQ.5-d142E70b_5aFhVlX8k9Y7zX9b8c7d6e5f4a3b2c1';
    v_fcm_secret TEXT := 'kasby_internal_fcm_secret_2026_x972f';
    v_auth_token TEXT;
BEGIN
    SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = NEW.user_id;
    
    IF v_recipient_fcm_token IS NOT NULL AND LENGTH(v_recipient_fcm_token) > 10 THEN
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
                        'route', COALESCE(NEW.deep_link, '/notifications'),
                        'deep_link', COALESCE(NEW.deep_link, '/notifications'),
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

-- Ensure AFTER INSERT trigger exists on public.notifications
DROP TRIGGER IF EXISTS "on_notification_inserted" ON "public"."notifications";
CREATE TRIGGER "on_notification_inserted" 
    AFTER INSERT ON "public"."notifications" 
    FOR EACH ROW 
    EXECUTE FUNCTION "public"."trigger_generic_notification"();


-- 2. Update fn_create_notification to rely on the on_notification_inserted trigger
CREATE OR REPLACE FUNCTION "public"."fn_create_notification"(
    "p_user_id" "uuid", 
    "p_title" "text", 
    "p_body" "text", 
    "p_type" "text" DEFAULT 'system'::"text", 
    "p_entity_type" "text" DEFAULT NULL::"text", 
    "p_entity_id" "text" DEFAULT NULL::"text", 
    "p_deep_link" "text" DEFAULT NULL::"text", 
    "p_role_target" "text" DEFAULT 'user'::"text", 
    "p_priority" "text" DEFAULT 'normal'::"text"
) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_notif_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id, title, message, type, entity_type, entity_id,
        deep_link, role_target, priority, status
    ) VALUES (
        p_user_id, p_title, p_body, p_type, p_entity_type, p_entity_id,
        p_deep_link, p_role_target, p_priority, 'sent'
    )
    RETURNING id INTO v_notif_id;

    -- FCM push delivery is handled cleanly by on_notification_inserted trigger
    RETURN v_notif_id;
END;
$$;

ALTER FUNCTION "public"."fn_create_notification"("p_user_id" "uuid", "p_title" "text", "p_body" "text", "p_type" "text", "p_entity_type" "text", "p_entity_id" "text", "p_deep_link" "text", "p_role_target" "text", "p_priority" "text") OWNER TO "postgres";


-- 3. Comprehensive fn_cron_distribute_daily_profits with investment plan details & deduplication
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
    v_plan_name_en TEXT;
    v_title_ar TEXT;
    v_body_ar TEXT;
    v_already_notified BOOLEAN;
BEGIN
    -- Check if profits are paused system-wide
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
            COALESCE(ip.name_ar, ip.name_en, 'خطة الاستثمار') AS plan_name_ar,
            COALESCE(ip.name_en, ip.name_ar, 'Investment Plan') AS plan_name_en
        FROM public.user_investments ui
        LEFT JOIN public.investment_plans ip ON ip.id = ui.plan_id
        WHERE ui.status = 'active'
          AND ui.next_payout_at IS NOT NULL
          AND NOW() >= ui.next_payout_at
        FOR UPDATE OF ui SKIP LOCKED
    LOOP
        -- Calculate daily profit
        v_profit := ROUND((v_inv.amount * (v_inv.profit_percentage / 100) / 365), 4);

        IF v_profit > 0 THEN
            SELECT id INTO v_wallet_id
            FROM public.wallets WHERE user_id = v_inv.user_id
            FOR UPDATE;

            IF v_wallet_id IS NOT NULL THEN
                -- 1. Update wallet balance
                UPDATE public.wallets
                SET available_balance = available_balance + v_profit,
                    profit_balance = profit_balance + v_profit,
                    updated_at = NOW()
                WHERE id = v_wallet_id;

                -- 2. Record profit transaction
                INSERT INTO public.transactions (
                    user_id, wallet_id, type, amount, status, description, running_balance
                ) VALUES (
                    v_inv.user_id, v_wallet_id, 'profit', v_profit, 'completed',
                    'أرباح يومية — ' || v_inv.plan_name_ar,
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id)
                );

                -- 3. Format profit amount cleanly
                v_profit_formatted := CASE 
                    WHEN v_profit = FLOOR(v_profit) THEN (v_profit::BIGINT)::TEXT
                    WHEN v_profit = ROUND(v_profit, 2) THEN TO_CHAR(v_profit, 'FM999999990.00')
                    ELSE RTRIM(RTRIM(TO_CHAR(v_profit, 'FM999999990.0000'), '0'), '.')
                END;

                -- 4. Deduplication Check: Ensure 1 payout = 1 notification
                SELECT EXISTS (
                    SELECT 1 FROM public.notifications
                    WHERE user_id = v_inv.user_id
                      AND type = 'daily_profit'
                      AND entity_id = v_inv.id::TEXT
                      AND created_at >= NOW() - INTERVAL '23 hours'
                ) INTO v_already_notified;

                -- 5. Create structured notification if not already notified
                IF NOT v_already_notified THEN
                    v_title_ar := 'أرباح استثمار جديدة 💰';
                    v_body_ar  := 'تم إضافة أرباح بقيمة $' || v_profit_formatted || ' من ' || v_inv.plan_name_ar;

                    PERFORM public.fn_create_notification(
                        v_inv.user_id,
                        v_title_ar,
                        v_body_ar,
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

        -- 6. Update investment cycle to advance to next 24-hour cycle
        UPDATE public.user_investments
        SET last_profit_at = NOW(),
            actual_profit = COALESCE(actual_profit, 0) + v_profit,
            next_payout_at = GREATEST(NOW(), v_inv.next_payout_at) + INTERVAL '24 hours'
        WHERE id = v_inv.id;

        -- 7. Maturity checks (collateral lock aware)
        IF v_inv.end_date IS NOT NULL AND v_inv.end_date <= NOW() THEN
            IF v_inv.is_collateral_locked THEN
                INSERT INTO public.system_logs (
                    actor_id, actor_role, action, entity_type, entity_id, details, severity
                ) VALUES (
                    NULL, 'system', 'maturity_held_by_collateral', 'investment', v_inv.id::TEXT,
                    jsonb_build_object(
                        'reason', 'Investment matured but is locked as collateral for an active loan',
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
