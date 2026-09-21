-- ============================================================
-- Migration: Harden fn_cron_distribute_daily_profits
-- Date: 2026-09-11
--
-- ROOT CAUSE (production incident since 2026-09-08):
--   The deployed fn_cron_distribute_daily_profits variant:
--     1. Threw `null value in column "wallet_id"` on the transactions insert,
--        and because every payout runs inside ONE transaction, that single
--        failure ROLLED BACK ALL payouts for ALL users (profits froze for
--        every user since ~2026-09-08).
--     2. Never processed or closed investments with auto_restart_enabled=false,
--        leaving them past-due forever -> the app kept calling the RPC every
--        second, amplifying the error flood.
--
-- FIX (this migration):
--   * Per-investment SAVEPOINT isolation: one bad investment can no longer
--     abort the batch. Failures are logged to system_logs and skipped.
--   * Wallet-safe payouts: resolve wallet (USD first, then ensure_user_wallet);
--     if it still cannot be resolved, SKIP with a log entry. A NULL wallet_id
--     can never reach the transactions insert.
--   * Processes ALL active due investments (not just auto_restart_enabled=true):
--       - auto true  -> pay daily profit, roll to NOW()+24h (no catch-up).
--       - auto false -> pay due cycle, then close cycle (next_payout_at=NULL)
--                       so the app shows "cycle completed" and the user can
--                       manually restart via fn_start_next_cycle.
--   * Profit formula: expected_profit / plan.duration_days (same as the app
--     display "Daily profit = totalProfit / duration_days" and the values
--     already paid in production: 0.10 / 0.20 daily on bronze plans).
--   * Returns JSON summary for observability.
-- ============================================================

BEGIN;

DROP FUNCTION IF EXISTS public.fn_cron_distribute_daily_profits() CASCADE;

CREATE OR REPLACE FUNCTION public.fn_cron_distribute_daily_profits()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_inv RECORD;
    v_profit NUMERIC(18,4);
    v_profit_formatted TEXT;
    v_wallet_id UUID;
    v_plan_total_days INT;
    v_plan_name_ar TEXT;
    v_already_notified BOOLEAN;
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
            -- Per-investment isolation: this nested exception block acts as an
            -- implicit savepoint, so a failure here must never abort the whole
            -- batch (root cause of the global payout freeze).

            v_plan_total_days := v_inv.plan_total_days;
            v_plan_name_ar := v_inv.plan_name_ar;

            -- Daily profit = expected_profit / duration_days (matches app & history)
            v_profit := ROUND((v_inv.expected_profit / NULLIF(v_plan_total_days, 0))::numeric, 2);

            IF v_profit IS NULL OR v_profit <= 0 THEN
                -- Degenerate investment (no plan / zero expected profit). Close the
                -- cycle without payouts so it can't stay due forever.
                UPDATE public.user_investments
                SET last_profit_at = v_now,
                    next_payout_at = NULL,
                    auto_restart_enabled = FALSE,
                    updated_at = v_now
                WHERE id = v_inv.id;
                v_skipped_count := v_skipped_count + 1;
                CONTINUE;
            END IF;

            -- Resolve wallet. Prefer USD, fall back to creating one if missing.
            SELECT id INTO v_wallet_id
            FROM public.wallets
            WHERE user_id = v_inv.user_id AND currency = 'USD'
            FOR UPDATE;

            IF v_wallet_id IS NULL THEN
                v_wallet_id := public.ensure_user_wallet(v_inv.user_id);
            END IF;

            IF v_wallet_id IS NULL THEN
                -- No wallet possible: skip silently but DO NOT touch next_payout_at,
                -- so a future run retries once a wallet exists. Log for ops.
                INSERT INTO public.system_logs (
                    actor_id, actor_role, action, entity_type, entity_id, details, severity
                ) VALUES (
                    NULL, 'system', 'profit_distribution_skipped_no_wallet', 'investment', v_inv.id::TEXT,
                    jsonb_build_object('user_id', v_inv.user_id, 'profit', v_profit), 'warning'
                );
                v_skipped_count := v_skipped_count + 1;
                CONTINUE;
            END IF;

            -- A. Credit wallet balances
            UPDATE public.wallets
            SET available_balance = available_balance + v_profit,
                profit_balance = profit_balance + v_profit,
                updated_at = v_now
            WHERE id = v_wallet_id;

            -- B. Record profit transaction (wallet_id is guaranteed non-null here)
            INSERT INTO public.transactions (
                user_id, wallet_id, type, amount, currency, status,
                description, reference_id, processed_at, running_balance
            ) VALUES (
                v_inv.user_id, v_wallet_id, 'profit', v_profit, 'USD', 'completed',
                'ربح يومي من ' || v_plan_name_ar, v_inv.id::TEXT, v_now,
                (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id)
            );

            -- C. Clean profit string for notifications
            v_profit_formatted := CASE
                WHEN v_profit = FLOOR(v_profit) THEN (v_profit::BIGINT)::TEXT
                WHEN v_profit = ROUND(v_profit, 2) THEN TO_CHAR(v_profit, 'FM999999990.00')
                ELSE RTRIM(RTRIM(TO_CHAR(v_profit, 'FM999999990.0000'), '0'), '.')
            END;

            -- D. Notification deduplication guard (1 payout = 1 notification, 23h window)
            SELECT EXISTS (
                SELECT 1 FROM public.notifications
                WHERE user_id = v_inv.user_id
                  AND type = 'daily_profit'
                  AND entity_id = v_inv.id::TEXT
                  AND created_at >= v_now - INTERVAL '23 hours'
            ) INTO v_already_notified;

            IF NOT v_already_notified THEN
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
            END IF;

            -- E. Subscription-aware cycle handling
            SELECT EXISTS (
                SELECT 1 FROM public.subscriptions
                WHERE user_id = v_inv.user_id
                  AND status = 'active'
                  AND (expires_at IS NULL OR expires_at > v_now)
            ) OR EXISTS (
                SELECT 1 FROM public.profiles
                WHERE id = v_inv.user_id AND account_tier IN ('premium', 'vip')
            ) INTO v_has_active_sub;

            v_should_auto_restart := v_has_active_sub AND v_inv.auto_restart_enabled;

            IF v_should_auto_restart THEN
                UPDATE public.user_investments
                SET last_profit_at = v_now,
                    actual_profit = COALESCE(actual_profit, 0) + v_profit,
                    next_payout_at = GREATEST(v_now, v_inv.next_payout_at) + INTERVAL '24 hours',
                    updated_at = v_now
                WHERE id = v_inv.id;
            ELSE
                -- Cycle completed: pause until manual restart (fn_start_next_cycle)
                UPDATE public.user_investments
                SET last_profit_at = v_now,
                    actual_profit = COALESCE(actual_profit, 0) + v_profit,
                    next_payout_at = NULL,
                    auto_restart_enabled = FALSE,
                    updated_at = v_now
                WHERE id = v_inv.id;
            END IF;

            v_processed_count := v_processed_count + 1;
            v_total_paid := v_total_paid + v_profit;

            -- F. Maturity handling (collateral-lock aware)
            IF v_inv.end_date IS NOT NULL AND v_inv.end_date <= v_now THEN
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
                SET status = 'matured', matured_at = v_now, next_payout_at = NULL, updated_at = v_now
                WHERE id = v_inv.id;

                UPDATE public.wallets
                SET available_balance = available_balance + v_inv.amount,
                    invested_balance = invested_balance - v_inv.amount,
                    updated_at = v_now
                WHERE id = v_wallet_id;

                INSERT INTO public.transactions (
                    user_id, wallet_id, type, amount, currency, status,
                    description, reference_id, processed_at, running_balance
                ) VALUES (
                    v_inv.user_id, v_wallet_id, 'investment_return', v_inv.amount, 'USD', 'completed',
                    'اكتمال الاستثمار — استعادة رأس المال', v_inv.id::TEXT, v_now,
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id)
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
            v_wallet_id := NULL;
            BEGIN
                INSERT INTO public.system_logs (
                    actor_id, actor_role, action, entity_type, entity_id, details, severity
                ) VALUES (
                    NULL, 'system', 'profit_distribution_failed', 'investment', v_inv.id::TEXT,
                    jsonb_build_object(
                        'user_id', v_inv.user_id,
                        'error', SQLERRM,
                        'profit', v_profit
                    ), 'error'
                );
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
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
GRANT EXECUTE ON FUNCTION public.fn_cron_distribute_daily_profits() TO authenticated;

-- Re-affirm server-side cron scheduling (every minute), idempotent
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
SELECT cron.unschedule('distribute-daily-profits-job')
WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'distribute-daily-profits-job');
SELECT cron.schedule(
    'distribute-daily-profits-job',
    '* * * * *',
    $$SELECT public.fn_cron_distribute_daily_profits()$$
);

COMMIT;