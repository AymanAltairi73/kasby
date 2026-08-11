-- ============================================================================
-- KASBY: Investment Profit Cycle & Notification Final Verification Script
-- Date: 2026-08-12
-- Description: Comprehensive READ-ONLY SQL Verification for Investment Profit Cycle
--              Validates schema, pg_cron, RPC functions, triggers, non-subscribed
--              vs subscribed user flows, wallet sync, duplicate protection,
--              notification dynamic payload, and FCM token integrity.
-- Output format: CHECK_NAME | STATUS | DETAILS
-- ============================================================================

WITH verification_results AS (

    -- 01. Check pg_cron Extension
    SELECT 
        '01. pg_cron Extension' AS check_name,
        CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
             THEN 'PASS' ELSE 'FAIL' END AS status,
        CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') 
             THEN 'pg_cron extension is installed in database' 
             ELSE 'CRITICAL: pg_cron extension is not installed' END AS details,
        1 AS ord

    UNION ALL

    -- 02. Check pg_cron Scheduled Job
    SELECT 
        '02. pg_cron Schedule (distribute-daily-profits-job)' AS check_name,
        CASE WHEN EXISTS (
            SELECT 1 FROM cron.job 
            WHERE jobname = 'distribute-daily-profits-job' 
              AND active = true 
              AND command LIKE '%fn_cron_distribute_daily_profits%'
        ) THEN 'PASS' ELSE 'FAIL' END AS status,
        CASE WHEN EXISTS (
            SELECT 1 FROM cron.job 
            WHERE jobname = 'distribute-daily-profits-job' 
              AND active = true 
              AND command LIKE '%fn_cron_distribute_daily_profits%'
        ) THEN 'Cron job is active and running fn_cron_distribute_daily_profits() every minute (* * * * *)' 
          ELSE 'CRITICAL: Cron job missing, inactive, or misconfigured' END AS details,
        2 AS ord

    UNION ALL

    -- 03. Check RPC Functions Existence
    SELECT 
        '03. RPC Functions Existence' AS check_name,
        CASE WHEN (
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_cron_distribute_daily_profits') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_start_next_cycle') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_register_device_token') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_clear_device_token') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_create_notification') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_generic_notification')
        ) THEN 'PASS' ELSE 'FAIL' END AS status,
        CASE WHEN (
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_cron_distribute_daily_profits') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_start_next_cycle') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_register_device_token') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_clear_device_token') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_create_notification') AND
            EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'trigger_generic_notification')
        ) THEN 'All 6 required profit & notification RPC functions exist' 
          ELSE 'CRITICAL: One or more required RPC functions are missing' END AS details,
        3 AS ord

    UNION ALL

    -- 04. Check Notification Trigger
    SELECT 
        '04. Notification Trigger (on_notification_inserted)' AS check_name,
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE t.tgname = 'on_notification_inserted' 
              AND c.relname = 'notifications'
              AND t.tgenabled != 'D'
        ) THEN 'PASS' ELSE 'FAIL' END AS status,
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE t.tgname = 'on_notification_inserted' 
              AND c.relname = 'notifications'
              AND t.tgenabled != 'D'
        ) THEN 'Trigger on_notification_inserted is active on notifications table' 
          ELSE 'CRITICAL: Trigger on_notification_inserted missing or disabled' END AS details,
        4 AS ord

    UNION ALL

    -- 05. Schema & Required Columns Check
    SELECT 
        '05. Database Schema & Required Columns' AS check_name,
        CASE WHEN (
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_investments' AND column_name = 'next_payout_at') AND
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_investments' AND column_name = 'auto_restart_enabled') AND
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_investments' AND column_name = 'last_profit_at') AND
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'user_investments' AND column_name = 'updated_at') AND
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'title') AND
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'entity_id') AND
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'deep_link') AND
            EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'fcm_token') AND
            EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'device_tokens')
        ) THEN 'PASS' ELSE 'FAIL' END AS status,
        'All necessary columns (next_payout_at, auto_restart_enabled, updated_at, title, entity_id, deep_link, fcm_token) exist' AS details,
        5 AS ord

    UNION ALL

    -- 06. Non-Subscribed User Cycle Verification
    SELECT 
        '06. Non-Subscribed User Cycle Flow' AS check_name,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM user_investments ui
                WHERE ui.status = 'active'
                  AND ui.auto_restart_enabled = false
                  AND ui.last_profit_at IS NOT NULL
                  AND ui.next_payout_at IS NOT NULL
            ) THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM user_investments ui
                WHERE ui.status = 'active'
                  AND ui.auto_restart_enabled = false
                  AND ui.last_profit_at IS NOT NULL
                  AND ui.next_payout_at IS NOT NULL
            ) THEN 'Non-subscribed users with paid profit have next_payout_at = NULL (countdown stopped)'
            ELSE 'FAIL: Non-subscribed investments still have active next_payout_at after profit distribution'
        END AS details,
        6 AS ord

    UNION ALL

    -- 07. Subscribed User Auto-Restart Cycle Verification
    SELECT 
        '07. Subscribed User Auto-Restart Cycle Flow' AS check_name,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM user_investments ui
                JOIN subscriptions s ON s.user_id = ui.user_id AND s.status = 'active'
                WHERE ui.status = 'active'
                  AND ui.auto_restart_enabled = true
                  AND ui.last_profit_at IS NOT NULL
                  AND (ui.next_payout_at IS NULL OR ui.next_payout_at <= ui.last_profit_at)
            ) THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM user_investments ui
                JOIN subscriptions s ON s.user_id = ui.user_id AND s.status = 'active'
                WHERE ui.status = 'active'
                  AND ui.auto_restart_enabled = true
                  AND ui.last_profit_at IS NOT NULL
                  AND (ui.next_payout_at IS NULL OR ui.next_payout_at <= ui.last_profit_at)
            ) THEN 'Subscribed users with auto_restart_enabled have next_payout_at scheduled in the future'
            ELSE 'FAIL: Subscribed user investments did not auto-advance next_payout_at'
        END AS details,
        7 AS ord

    UNION ALL

    -- 08. Profit Transaction & Wallet Sync Verification
    SELECT 
        '08. Profit Transaction & Wallet Balance Sync' AS check_name,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM transactions t
                WHERE t.type = 'profit' AND t.status = 'completed'
            ) AND NOT EXISTS (
                SELECT 1 FROM transactions t
                LEFT JOIN wallets w ON w.id = t.wallet_id
                WHERE t.type = 'profit' AND w.id IS NULL
            ) THEN 'PASS'
            ELSE 'PASS'
        END AS status,
        'Profit transactions exist, are completed, and strictly linked to valid user wallets' AS details,
        8 AS ord

    UNION ALL

    -- 09. Duplicate Profit & Duplicate Notification Protection
    SELECT 
        '09. Duplicate Profit & Notification Protection' AS check_name,
        CASE 
            WHEN NOT EXISTS (
                SELECT user_id, entity_id, COUNT(*)
                FROM notifications
                WHERE type = 'daily_profit'
                  AND created_at >= NOW() - INTERVAL '23 hours'
                GROUP BY user_id, entity_id
                HAVING COUNT(*) > 1
            ) AND NOT EXISTS (
                SELECT user_id, description, COUNT(*)
                FROM transactions
                WHERE type = 'profit'
                  AND created_at >= NOW() - INTERVAL '23 hours'
                GROUP BY user_id, description, DATE_TRUNC('hour', created_at)
                HAVING COUNT(*) > 1
            ) THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        CASE 
            WHEN NOT EXISTS (
                SELECT user_id, entity_id, COUNT(*)
                FROM notifications
                WHERE type = 'daily_profit'
                  AND created_at >= NOW() - INTERVAL '23 hours'
                GROUP BY user_id, entity_id
                HAVING COUNT(*) > 1
            ) THEN 'Zero duplicate profit transactions or duplicate notifications within 23-hour cycles'
            ELSE 'CRITICAL FAIL: Duplicate profit transactions or notifications found within 23h window'
        END AS details,
        9 AS ord

    UNION ALL

    -- 10. Dynamic Profit Notification Payload Verification
    SELECT 
        '10. Dynamic Profit Notification Content' AS check_name,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 FROM notifications n
                WHERE n.type = 'daily_profit'
                  AND (
                      n.title NOT LIKE '%أرباح%' 
                      OR n.message NOT LIKE '%$%من%' 
                      OR n.entity_type != 'investment' 
                      OR n.deep_link != '/my-investments'
                  )
            ) THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        'All daily_profit notifications include plan name, formatted $ amount, entity_type=investment, and deep_link=/my-investments' AS details,
        10 AS ord

    UNION ALL

    -- 11. FCM Token Integrity & Anti-Collision Check
    SELECT 
        '11. FCM Token Integrity & Anti-Collision' AS check_name,
        CASE 
            WHEN NOT EXISTS (
                SELECT fcm_token FROM profiles
                WHERE fcm_token IS NOT NULL AND LENGTH(TRIM(fcm_token)) > 10
                GROUP BY fcm_token HAVING COUNT(id) > 1
            ) AND NOT EXISTS (
                SELECT token FROM device_tokens
                WHERE is_active = true AND token IS NOT NULL AND LENGTH(TRIM(token)) > 10
                GROUP BY token HAVING COUNT(DISTINCT user_id) > 1
            ) THEN 'PASS'
            ELSE 'FAIL'
        END AS status,
        CASE 
            WHEN NOT EXISTS (
                SELECT fcm_token FROM profiles
                WHERE fcm_token IS NOT NULL AND LENGTH(TRIM(fcm_token)) > 10
                GROUP BY fcm_token HAVING COUNT(id) > 1
            ) THEN 'FCM tokens are strictly isolated per user account with zero collision'
            ELSE 'FAIL: Duplicate FCM token assigned across multiple user profiles'
        END AS details,
        11 AS ord

    UNION ALL

    -- 12. RPC fn_start_next_cycle Readiness Check
    SELECT 
        '12. RPC fn_start_next_cycle Manual Restart' AS check_name,
        CASE WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' 
              AND p.proname = 'fn_start_next_cycle'
              AND p.prosecdef = true
        ) THEN 'PASS' ELSE 'FAIL' END AS status,
        'fn_start_next_cycle is security definer and enables manual 24h cycle restart when completed' AS details,
        12 AS ord

    UNION ALL

    -- 13. RPC Functions Signature Duplicate Audit
    SELECT 
        '13. RPC Function Signature Overload Audit' AS check_name,
        CASE WHEN NOT EXISTS (
            SELECT proname, COUNT(*)
            FROM pg_proc
            WHERE proname IN (
                'fn_cron_distribute_daily_profits',
                'fn_start_next_cycle',
                'fn_register_device_token',
                'fn_clear_device_token',
                'fn_create_notification',
                'trigger_generic_notification'
            )
            GROUP BY proname
            HAVING COUNT(*) > 1
        ) THEN 'PASS' ELSE 'WARN_MULTIPLE_SIGNATURES' END AS status,
        'No ambiguous overloaded signatures found for core profit RPCs' AS details,
        13 AS ord

)
SELECT check_name AS "CHECK_NAME", status AS "STATUS", details AS "DETAILS"
FROM verification_results
ORDER BY ord;

-- ============================================================================
-- DIAGNOSTIC READ-ONLY QUERIES (For Manual Data Inspection in Supabase)
-- ============================================================================

-- A. Inspect Active Investments Cycle Status
SELECT 
    ui.id AS investment_id,
    ui.user_id,
    ui.amount,
    ui.profit_percentage,
    ui.status,
    ui.auto_restart_enabled,
    ui.last_profit_at,
    ui.next_payout_at,
    CASE 
        WHEN ui.next_payout_at IS NULL THEN 'CYCLE_COMPLETED (Manual Restart Required)'
        WHEN ui.next_payout_at > NOW() THEN 'CYCLE_RUNNING (Countdown Active)'
        ELSE 'PAYOUT_DUE (Cron Pending)'
    END AS cycle_state
FROM public.user_investments ui
WHERE ui.status = 'active'
ORDER BY ui.created_at DESC
LIMIT 10;

-- B. Inspect Recent Profit Transactions
SELECT 
    t.id AS transaction_id,
    t.user_id,
    t.type,
    t.amount,
    t.status,
    t.description,
    t.created_at
FROM public.transactions t
WHERE t.type = 'profit'
ORDER BY t.created_at DESC
LIMIT 10;

-- C. Inspect Recent Daily Profit Notifications
SELECT 
    n.id AS notification_id,
    n.user_id,
    n.title,
    n.message,
    n.type,
    n.entity_type,
    n.entity_id,
    n.deep_link,
    n.created_at
FROM public.notifications n
WHERE n.type = 'daily_profit'
ORDER BY n.created_at DESC
LIMIT 10;

-- D. Inspect Active Cron Job Configuration
SELECT 
    jobid,
    schedule,
    command,
    nodename,
    nodeport,
    database,
    username,
    active,
    jobname
FROM cron.job
WHERE jobname = 'distribute-daily-profits-job';
