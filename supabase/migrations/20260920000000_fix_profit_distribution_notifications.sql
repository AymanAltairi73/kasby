-- ============================================================================
-- Migration: 20260920000000_fix_profit_distribution_notifications.sql
-- Date: 2026-09-20
-- Description: Comprehensive End-to-End Fix for Profit Distribution & Notifications
--   1. Fix fn_cron_distribute_daily_profits:
--      - Use canonical transaction type 'profit' (resolves transactions_type_check violation)
--      - Server-side duplicate payout protection guard (20h window)
--      - Atomic wallet credit + transaction record + notification creation
--   2. Enhance fn_localize_notification_before_insert:
--      - Match profit notification patterns ('تم إضافة أرباح' / 'تمت إضافة ربح')
--      - Populate title_key, message_key, parameters for dynamic bilingual localization
--   3. Enhance trigger_generic_notification:
--      - True multi-device FCM push delivery across all distinct active tokens
--      - Safe fallback to profile token without stale-token blocking
--      - Isolated per-device error handling
-- ============================================================================

-- ─── 1. FIX fn_cron_distribute_daily_profits ────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_cron_distribute_daily_profits()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inv RECORD;
    v_profit NUMERIC(18,4);
    v_profit_formatted TEXT;
    v_wallet_id UUID;
    v_txn_id UUID;
    v_plan_name_ar TEXT;
    v_plan_total_days INT;
    v_has_active_sub BOOLEAN;
    v_should_auto_restart BOOLEAN;
    v_now TIMESTAMPTZ := NOW();
    v_processed_count INT := 0;
    v_skipped_count INT := 0;
    v_total_paid NUMERIC(18,4) := 0.00;
BEGIN
    -- Safety pause guard
    IF EXISTS (SELECT 1 FROM public.system_settings WHERE pause_profits = TRUE LIMIT 1) THEN
        RETURN json_build_object(
            'success', true,
            'processed_count', 0,
            'skipped_count', 0,
            'total_paid', 0,
            'paused', true
        );
    END IF;

    FOR v_inv IN
        SELECT
            ui.id,
            ui.user_id,
            ui.plan_id,
            ui.amount,
            ui.profit_percentage,
            ui.expected_profit,
            ui.actual_profit,
            ui.end_date,
            ui.is_collateral_locked,
            ui.next_payout_at,
            ui.auto_restart_enabled,
            COALESCE(ip.name_ar, ip.name_en, 'خطة الاستثمار') AS plan_name_ar,
            COALESCE(ip.duration_days, 30) AS plan_total_days
        FROM public.user_investments ui
        LEFT JOIN public.investment_plans ip ON ip.id = ui.plan_id
        WHERE ui.status = 'active'
          AND ui.next_payout_at IS NOT NULL
          AND v_now >= ui.next_payout_at
        FOR UPDATE OF ui SKIP LOCKED
    LOOP
        BEGIN
            v_plan_total_days := v_inv.plan_total_days;
            v_plan_name_ar := v_inv.plan_name_ar;

            -- Authoritative daily profit calculation = expected_profit / duration_days
            v_profit := ROUND((v_inv.expected_profit / NULLIF(v_plan_total_days, 0))::numeric, 2);

            IF v_profit IS NULL OR v_profit <= 0 THEN
                -- Degenerate investment: close cycle without payout
                UPDATE public.user_investments
                SET last_profit_at = v_now,
                    status = 'not_active',
                    next_payout_at = NULL,
                    auto_restart_enabled = FALSE,
                    updated_at = v_now
                WHERE id = v_inv.id;
                v_skipped_count := v_skipped_count + 1;
                CONTINUE;
            END IF;

            -- Prevent exceeding total expected profit
            IF COALESCE(v_inv.actual_profit, 0) + v_profit > v_inv.expected_profit THEN
                v_profit := GREATEST(0.00, v_inv.expected_profit - COALESCE(v_inv.actual_profit, 0));
                IF v_profit <= 0 THEN
                    UPDATE public.user_investments
                    SET status = 'matured',
                        matured_at = v_now,
                        next_payout_at = NULL,
                        updated_at = v_now
                    WHERE id = v_inv.id;
                    v_skipped_count := v_skipped_count + 1;
                    CONTINUE;
                END IF;
            END IF;

            -- Resolve user USD wallet
            SELECT id INTO v_wallet_id
            FROM public.wallets
            WHERE user_id = v_inv.user_id AND currency = 'USD'
            FOR UPDATE;

            IF v_wallet_id IS NULL THEN
                v_wallet_id := public.ensure_user_wallet(v_inv.user_id);
            END IF;

            IF v_wallet_id IS NULL THEN
                INSERT INTO public.system_logs (
                    actor_id, actor_role, action, entity_type, entity_id, details, severity
                ) VALUES (
                    NULL, 'system', 'profit_distribution_missing_wallet', 'investment', v_inv.id::TEXT,
                    jsonb_build_object(
                        'reason', 'User wallet USD could not be resolved or created',
                        'user_id', v_inv.user_id,
                        'profit_amount', v_profit
                    ), 'error'
                );
                v_skipped_count := v_skipped_count + 1;
                CONTINUE;
            END IF;

            -- Check subscription-aware auto-restart eligibility
            SELECT EXISTS (
                SELECT 1 FROM public.subscriptions
                WHERE user_id = v_inv.user_id
                  AND status = 'active'
                  AND (COALESCE(expires_at, end_date) IS NULL OR COALESCE(expires_at, end_date) > v_now)
            ) INTO v_has_active_sub;

            v_should_auto_restart := v_has_active_sub AND v_inv.auto_restart_enabled;

            -- ── SERVER-SIDE IDEMPOTENCY / DOUBLE-PAYMENT GUARD ──
            IF EXISTS (
                SELECT 1 FROM public.transactions
                WHERE user_id = v_inv.user_id
                  AND wallet_id = v_wallet_id
                  AND type = 'profit'
                  AND reference_id = v_inv.id::TEXT
                  AND created_at >= v_now - INTERVAL '20 hours'
            ) THEN
                -- Already distributed today: advance next_payout_at safely without double payment
                IF v_should_auto_restart THEN
                    UPDATE public.user_investments
                    SET next_payout_at = GREATEST(v_now, v_inv.next_payout_at) + INTERVAL '24 hours',
                        updated_at = v_now
                    WHERE id = v_inv.id;
                ELSE
                    UPDATE public.user_investments
                    SET status = 'not_active',
                        next_payout_at = NULL,
                        auto_restart_enabled = FALSE,
                        updated_at = v_now
                    WHERE id = v_inv.id;
                END IF;
                v_skipped_count := v_skipped_count + 1;
                CONTINUE;
            END IF;

            -- A. Credit wallet
            UPDATE public.wallets
            SET available_balance = available_balance + v_profit,
                profit_balance = profit_balance + v_profit,
                updated_at = v_now
            WHERE id = v_wallet_id;

            -- B. Insert profit transaction (using canonical type 'profit' to satisfy transactions_type_check)
            v_txn_id := gen_random_uuid();
            INSERT INTO public.transactions (
                id,
                user_id,
                wallet_id,
                type,
                amount,
                fee,
                currency,
                status,
                description,
                reference_id,
                running_balance,
                processed_at,
                created_at,
                updated_at
            ) VALUES (
                v_txn_id,
                v_inv.user_id,
                v_wallet_id,
                'profit',
                v_profit,
                0,
                'USD',
                'completed',
                'أرباح يومية من ' || v_plan_name_ar,
                v_inv.id::TEXT,
                (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id),
                v_now,
                v_now,
                v_now
            );

            -- C. Format profit amount for notification
            v_profit_formatted := CASE
                WHEN v_profit = FLOOR(v_profit) THEN (v_profit::BIGINT)::TEXT
                WHEN v_profit = ROUND(v_profit, 2) THEN TO_CHAR(v_profit, 'FM999999990.00')
                ELSE RTRIM(RTRIM(TO_CHAR(v_profit, 'FM999999990.0000'), '0'), '.')
            END;

            -- D. Create In-App & FCM Notification
            PERFORM public.fn_create_notification(
                v_inv.user_id,
                'أرباح استثمار جديدة 💰',
                'تم إضافة أرباح بقيمة $' || v_profit_formatted || ' من ' || v_plan_name_ar,
                'daily_profit',
                'investment',
                v_inv.id::TEXT,
                '/my-investments',
                'user',
                'normal'
            );

            -- E. Subscription-aware cycle progression
            IF v_should_auto_restart THEN
                UPDATE public.user_investments
                SET last_profit_at = v_now,
                    actual_profit = COALESCE(actual_profit, 0) + v_profit,
                    next_payout_at = GREATEST(v_now, v_inv.next_payout_at) + INTERVAL '24 hours',
                    updated_at = v_now
                WHERE id = v_inv.id;
            ELSE
                UPDATE public.user_investments
                SET last_profit_at = v_now,
                    actual_profit = COALESCE(actual_profit, 0) + v_profit,
                    status = 'not_active',
                    next_payout_at = NULL,
                    auto_restart_enabled = FALSE,
                    updated_at = v_now
                WHERE id = v_inv.id;
            END IF;

            v_processed_count := v_processed_count + 1;
            v_total_paid := v_total_paid + v_profit;

            -- F. Maturity handling
            IF (v_inv.end_date IS NOT NULL AND v_inv.end_date <= v_now)
               OR (COALESCE(v_inv.actual_profit, 0) + v_profit >= v_inv.expected_profit) THEN
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
                SET status = 'matured',
                    matured_at = v_now,
                    next_payout_at = NULL,
                    updated_at = v_now
                WHERE id = v_inv.id;

                UPDATE public.wallets
                SET available_balance = available_balance + v_inv.amount,
                    invested_balance = invested_balance - v_inv.amount,
                    updated_at = v_now
                WHERE id = v_wallet_id;

                INSERT INTO public.transactions (
                    id, user_id, wallet_id, type, amount, fee, currency, status,
                    description, reference_id, running_balance, processed_at, created_at, updated_at
                ) VALUES (
                    gen_random_uuid(), v_inv.user_id, v_wallet_id, 'investment_return', v_inv.amount, 0, 'USD', 'completed',
                    'اكتمال الاستثمار — استعادة رأس المال', v_inv.id::TEXT,
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id),
                    v_now, v_now, v_now
                );

                PERFORM public.fn_create_notification(
                    v_inv.user_id,
                    'اكتمل الاستثمار 🎉',
                    'اكتملت مدة استثمارك في ' || v_plan_name_ar || ' وتم إرجاع رأس المال بمبلغ $' || (v_inv.amount::BIGINT)::TEXT || ' إلى محفظتك.',
                    'investment_matured',
                    'investment',
                    v_inv.id::TEXT,
                    '/my-investments',
                    'user',
                    'high'
                );
            END IF;

        EXCEPTION WHEN OTHERS THEN
            v_skipped_count := v_skipped_count + 1;
            INSERT INTO public.system_logs (
                actor_id, actor_role, action, entity_type, entity_id, details, severity
            ) VALUES (
                NULL, 'system', 'profit_distribution_item_exception', 'investment', v_inv.id::TEXT,
                jsonb_build_object(
                    'error', SQLERRM,
                    'user_id', v_inv.user_id,
                    'amount', v_inv.amount
                ), 'error'
            );
        END;
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'processed_count', v_processed_count,
        'skipped_count', v_skipped_count,
        'total_paid', v_total_paid
    );
END;
$$;

ALTER FUNCTION public.fn_cron_distribute_daily_profits() OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.fn_cron_distribute_daily_profits() TO authenticated, service_role, postgres;


-- ─── 2. ENHANCE fn_localize_notification_before_insert ───────────────────────

CREATE OR REPLACE FUNCTION public.fn_localize_notification_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_lang TEXT := 'ar';
    v_t_key TEXT := NEW.title_key;
    v_m_key TEXT := NEW.message_key;
    v_params JSONB := COALESCE(NEW.parameters, '{}'::jsonb);
    v_title TEXT := COALESCE(NEW.title, '');
    v_msg TEXT := COALESCE(NEW.message, '');
    v_loc_title TEXT;
    v_loc_msg TEXT;
    v_match TEXT[];
    v_plan_en TEXT;
BEGIN
    -- 1. Fetch recipient language
    IF NEW.user_id IS NOT NULL THEN
        SELECT COALESCE(language, 'ar') INTO v_user_lang
        FROM public.profiles
        WHERE id = NEW.user_id;
        IF v_user_lang NOT IN ('ar', 'en') THEN
            v_user_lang := 'ar';
        END IF;
    END IF;

    -- 2. Structured & Regexp Pattern Recognition
    IF v_t_key IS NULL OR v_t_key = '' THEN
        -- Daily Profit / Investment Profits
        IF v_title LIKE '%أرباح استثمار جديدة%' OR v_title LIKE '%New Investment Profit%' OR NEW.type = 'daily_profit' THEN
            -- Pattern 1: 'تم إضافة أرباح بقيمة $X من PLAN' OR 'تمت إضافة ربح بقيمة $X من PLAN'
            v_match := regexp_matches(v_msg, 'تم(?:ت)?\s*إضافة\s*(?:أرباح|ربح)\s*بقيمة\s*(\$?[\d\.]+)\s*من\s*(.+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_new_investment_profit_title';
                v_m_key := 'notif_new_investment_profit_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'plan', v_match[2]);
            ELSE
                -- Pattern 2: 'تم إضافة ربح بقيمة $X من استثمار (PLAN)'
                v_match := regexp_matches(v_msg, 'تم(?:ت)?\s*إضافة\s*(?:أرباح|ربح)\s*بقيمة\s*(\$?[\d\.]+)\s*من استثمار\s*\((.+?)\)');
                IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                    v_t_key := 'notif_daily_profit_received_title';
                    v_m_key := 'notif_daily_profit_received_msg';
                    v_params := jsonb_build_object('amount', v_match[1], 'plan', v_match[2]);
                ELSE
                    -- Pattern 3: 'تمت إضافة أرباح بقيمة $X إلى محفظتك'
                    v_match := regexp_matches(v_msg, 'تم(?:ت)?\s*إضافة\s*أرباح\s*بقيمة\s*(\$?[\d\.]+)\s*إلى محفظتك');
                    IF v_match IS NOT NULL AND array_length(v_match, 1) >= 1 THEN
                        v_t_key := 'notif_daily_profits_title';
                        v_m_key := 'notif_daily_profits_wallet_msg';
                        v_params := jsonb_build_object('amount', v_match[1]);
                    END IF;
                END IF;
            END IF;

        -- Investment Matured
        ELSIF v_title LIKE '%اكتمل الاستثمار%' OR v_title LIKE '%Investment Matured%' OR NEW.type = 'investment_matured' THEN
            v_match := regexp_matches(v_msg, 'اكتملت مدة استثمارك في\s*(.+?)\s*وتم إرجاع رأس المال بمبلغ\s*(\$?[\d\.]+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_investment_matured_title';
                v_m_key := 'notif_investment_matured_msg';
                v_params := jsonb_build_object('plan', v_match[1], 'amount', v_match[2]);
            ELSE
                v_match := regexp_matches(v_msg, 'اكتمل استثمارك في\s*(.+?)\s*وتمت استعادة رأس المال بقيمة\s*(\$?[\d\.]+)');
                IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                    v_t_key := 'notif_investment_matured_title';
                    v_m_key := 'notif_investment_matured_msg';
                    v_params := jsonb_build_object('plan', v_match[1], 'amount', v_match[2]);
                END IF;
            END IF;

        -- KSP Points Redeem
        ELSIF v_title LIKE '%نقاط KSP%' OR v_title LIKE '%KSP Points%' OR NEW.type = 'ksp_redeem' OR NEW.type = 'points_redeemed' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل\s*(\d+)\s*نقطة وإيداع\s*(\$?[\d\.]+)\s*في رصيدك النقدي');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_ksp_redeem_success_title';
                v_m_key := 'notif_ksp_redeem_success_msg';
                v_params := jsonb_build_object('points', v_match[1], 'amount', v_match[2]);
            END IF;

        -- Transfers: Cash Sent
        ELSIF v_title = 'تم إرسال التحويل' OR NEW.type = 'transfer_sent' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل\s*(\$?[\d\.]+)\s*(?:USD\s*)?إلى\s*(.+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_transfer_sent_title';
                v_m_key := 'notif_transfer_sent_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'user', v_match[2]);
            END IF;

        -- Transfers: Cash Received
        ELSIF v_title = 'تم استلام تحويل' OR NEW.type = 'transfer_received' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل مبلغ\s*(\$?[\d\.]+)\s*(?:USD\s*)?إليك من\s*(.+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_transfer_received_title';
                v_m_key := 'notif_transfer_received_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'user', v_match[2]);
            END IF;

        -- Deposits
        ELSIF v_title LIKE '%Deposit Request Submitted%' OR v_title = 'تم تقديم طلب الإيداع' OR NEW.type = 'deposit_submitted' THEN
            v_t_key := 'notif_deposit_submitted_title';
            v_m_key := 'notif_deposit_submitted_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        ELSIF v_title LIKE '%Deposit Approved%' OR v_title = 'تمت الموافقة على الإيداع' OR NEW.type = 'deposit_approved' THEN
            v_t_key := 'notif_deposit_approved_title';
            v_m_key := 'notif_deposit_approved_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        -- Withdrawals
        ELSIF v_title LIKE '%Withdrawal Request Submitted%' OR v_title = 'تم تقديم طلب السحب' OR NEW.type = 'withdrawal_requested' THEN
            v_t_key := 'notif_withdrawal_submitted_title';
            v_m_key := 'notif_withdrawal_submitted_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        ELSIF v_title LIKE '%Withdrawal Confirmed%' OR v_title LIKE '%Withdrawal Completed%' OR v_title = 'تم تأكيد السحب' OR NEW.type = 'withdrawal_completed' THEN
            v_t_key := 'notif_withdrawal_confirmed_title';
            v_m_key := 'notif_withdrawal_confirmed_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        -- Loans
        ELSIF v_title LIKE '%مبروك%' OR v_title LIKE '%Congratulations%' OR NEW.type = 'loan_approved' THEN
            v_t_key := 'notif_loan_approved_title';
            v_m_key := 'notif_loan_approved_msg';

        ELSIF v_title LIKE '%طلب سلفة%' OR v_title LIKE '%Loan Request%' OR NEW.type = 'loan_requested' THEN
            v_match := regexp_matches(v_msg, 'تم استلام طلب السلفة بقيمة\s*(.+?)\s*وهو قيد المراجعة');
            v_t_key := 'notif_loan_requested_title';
            v_m_key := 'notif_loan_requested_msg';
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        -- KYC
        ELSIF v_title LIKE '%توثيق الحساب%' OR v_title LIKE '%Account Verified%' OR NEW.type = 'kyc_verified' THEN
            v_t_key := 'notif_kyc_verified_title';
            v_m_key := 'notif_kyc_verified_msg';

        -- Referral Bonus
        ELSIF v_title LIKE '%عمولة إحالة%' OR v_title LIKE '%Referral Commission%' OR NEW.type = 'referral_bonus' THEN
            v_match := regexp_matches(v_msg, 'عمولة\s*(\$?[\d\.]+)\s*من استثمار\s*(.+)');
            v_t_key := 'notif_referral_commission_title';
            v_m_key := 'notif_referral_commission_msg';
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_params := jsonb_build_object('amount', v_match[1], 'user', v_match[2]);
            END IF;
        END IF;
    END IF;

    -- 3. Plan Name Localization (if English and plan param present)
    IF v_user_lang = 'en' AND v_params ? 'plan' THEN
        SELECT COALESCE(name_en, name_ar) INTO v_plan_en
        FROM public.investment_plans
        WHERE name_ar = (v_params->>'plan') OR name_en = (v_params->>'plan')
        LIMIT 1;

        IF v_plan_en IS NOT NULL AND v_plan_en <> '' THEN
            v_params := jsonb_set(v_params, '{plan}', to_jsonb(v_plan_en));
        END IF;
    END IF;

    -- 4. Set keys & parameters on NEW row
    IF v_t_key IS NOT NULL THEN
        NEW.title_key := v_t_key;
    END IF;
    IF v_m_key IS NOT NULL THEN
        NEW.message_key := v_m_key;
    END IF;
    IF v_params IS NOT NULL AND v_params <> '{}'::jsonb THEN
        NEW.parameters := v_params;
    END IF;

    -- 5. Localize title & message into user's language
    IF v_t_key IS NOT NULL THEN
        v_loc_title := public.fn_get_notification_translation(v_t_key, v_user_lang, v_params);
        IF v_loc_title IS NOT NULL AND v_loc_title <> '' THEN
            NEW.title := v_loc_title;
        END IF;
    END IF;

    IF v_m_key IS NOT NULL THEN
        v_loc_msg := public.fn_get_notification_translation(v_m_key, v_user_lang, v_params);
        IF v_loc_msg IS NOT NULL AND v_loc_msg <> '' THEN
            NEW.message := v_loc_msg;
        END IF;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RETURN NEW;
END;
$$;


-- ─── 3. ENHANCE trigger_generic_notification (MULTI-DEVICE DELIVERY) ───────

CREATE OR REPLACE FUNCTION "public"."trigger_generic_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_rec RECORD;
    v_project_url TEXT := 'https://your-project.supabase.co';
    v_service_key TEXT := 'YOUR_SERVICE_ROLE_KEY_HERE';
    v_fcm_secret TEXT := 'YOUR_FCM_SECRET_HERE';
    v_auth_token TEXT := COALESCE(v_fcm_secret, v_service_key);
BEGIN
    -- Query all distinct active tokens for the recipient (multi-device support)
    FOR v_rec IN
        SELECT DISTINCT token FROM (
            SELECT token FROM public.device_tokens 
            WHERE user_id = NEW.user_id AND is_active = TRUE AND token IS NOT NULL AND LENGTH(TRIM(token)) > 10
            UNION
            SELECT fcm_token AS token FROM public.profiles 
            WHERE id = NEW.user_id AND fcm_token IS NOT NULL AND LENGTH(TRIM(fcm_token)) > 10
        ) active_tokens
    LOOP
        BEGIN
            PERFORM net.http_post(
                url := v_project_url || '/functions/v1/send-fcm',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_auth_token
                ),
                body := jsonb_build_object(
                    'token', v_rec.token,
                    'title', COALESCE(NEW.title, 'Kasby Notification'),
                    'body', COALESCE(NEW.message, ''),
                    'data', jsonb_build_object(
                        'id', NEW.id::TEXT,
                        'type', COALESCE(NEW.type, 'notification'),
                        'entity_type', COALESCE(NEW.entity_type, ''),
                        'entity_id', COALESCE(NEW.entity_id, ''),
                        'route', COALESCE(NEW.deep_link, '/my-investments'),
                        'deep_link', COALESCE(NEW.deep_link, '/my-investments'),
                        'role_target', COALESCE(NEW.role_target, 'user'),
                        'title_key', COALESCE(NEW.title_key, ''),
                        'message_key', COALESCE(NEW.message_key, ''),
                        'parameters', COALESCE(NEW.parameters::TEXT, '{}')
                    )
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Generic notification FCM trigger failed for token %: %', v_rec.token, SQLERRM;
        END;
    END LOOP;

    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."trigger_generic_notification"() OWNER TO "postgres";

-- Ensure trigger is attached and active
DROP TRIGGER IF EXISTS "on_notification_inserted" ON "public"."notifications";
CREATE TRIGGER "on_notification_inserted" 
    AFTER INSERT ON "public"."notifications" 
    FOR EACH ROW 
    EXECUTE FUNCTION "public"."trigger_generic_notification"();
