-- ==============================================================================
-- Migration: Non-Subscribed Investment Lifecycle Hardening
-- Version: 20260912000000_non_subscribed_investment_lifecycle.sql
--
-- BUSINESS RULES ENFORCED:
-- 1. NON-SUBSCRIBED USER CREATION:
--    - Investment created with status = 'not_active'
--    - next_payout_at = NULL (NO automatic cycle, NO countdown, NO profit generated)
--    - auto_restart_enabled = FALSE
--    - Wallet principal debited ONCE during creation.
--
-- 2. START INVESTMENT CYCLE (fn_start_next_cycle):
--    - Authenticated user & ownership validation (auth.uid() = user_id)
--    - Row-lock (FOR UPDATE)
--    - Eligible if status = 'not_active' OR (status = 'active' AND (next_payout_at IS NULL OR next_payout_at <= NOW()))
--    - Rejects if cycle already running (next_payout_at > NOW())
--    - Rejects if status IN ('matured', 'completed', 'cancelled')
--    - ZERO financial modification (does not touch wallet or transactions)
--    - Authoritatively checks public.subscriptions to set auto_restart_enabled
--    - Sets status = 'active', next_payout_at = NOW() + INTERVAL '24 hours'
--
-- 3. PROFIT DISTRIBUTION & CYCLE COMPLETION (fn_cron_distribute_daily_profits):
--    - Evaluates active subscriptions solely via public.subscriptions (never stale profile tier)
--    - For non-subscribed users:
--      * Credits profit exactly once to wallet
--      * Records profit transaction & notification exactly once
--      * Returns investment to status = 'not_active', next_payout_at = NULL, auto_restart_enabled = FALSE
--      * Shows "Start Investment Cycle" button again in UI
--    - For subscribed users (active subscription & auto_restart_enabled = true):
--      * Credits profit and advances next_payout_at = GREATEST(now, next_payout_at) + 24 hours
-- ==============================================================================

-- ── 0. Drop existing functions to avoid 42P13 return type conflicts ──────────
DROP FUNCTION IF EXISTS public.fn_toggle_auto_restart(uuid, boolean) CASCADE;
DROP FUNCTION IF EXISTS public.fn_start_next_cycle(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.fn_cron_distribute_daily_profits() CASCADE;
DROP FUNCTION IF EXISTS public.fn_create_investment(uuid, uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.fn_create_investment(uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.create_investment(uuid, uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.create_investment(uuid, numeric, text) CASCADE;

-- ── 1. Update fn_create_investment ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_create_investment(
    p_user_id uuid,
    p_plan_id uuid,
    p_amount numeric,
    p_idempotency_key text DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := COALESCE(p_user_id, auth.uid());
    v_wid UUID;
    v_bal NUMERIC(18,4);
    v_frozen BOOLEAN;
    v_pct NUMERIC(6,3);
    v_min NUMERIC(18,4);
    v_max NUMERIC(18,4);
    v_active BOOLEAN;
    v_dur INTEGER;
    v_plan_title TEXT;
    v_txn UUID;
    v_inv UUID;
    v_has_active_sub BOOLEAN := FALSE;
    v_existing_tx UUID;
    v_existing_inv UUID;
BEGIN
    -- Session guard
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول');
    END IF;

    -- Idempotency check: prevent duplicate debits on retries
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id INTO v_existing_tx
        FROM public.transactions
        WHERE idempotency_key = p_idempotency_key
          AND user_id = v_user_id AND type = 'investment'
        LIMIT 1;
        IF v_existing_tx IS NOT NULL THEN
            SELECT id INTO v_existing_inv
            FROM public.user_investments
            WHERE transaction_id = v_existing_tx
            LIMIT 1;
            IF v_existing_inv IS NOT NULL THEN
                RETURN json_build_object(
                    'success', true,
                    'message', 'تم تنفيذ هذه العملية مسبقاً',
                    'investment_id', v_existing_inv
                );
            END IF;
        END IF;
    END IF;

    -- Global investment pause check
    IF EXISTS (SELECT 1 FROM public.system_settings WHERE pause_investments = TRUE LIMIT 1) THEN
        RETURN json_build_object('success', false, 'error', 'الاستثمارات موقوفة مؤقتاً');
    END IF;

    -- Plan validation
    SELECT profit_percentage, min_amount, max_amount, is_active, duration_days, COALESCE(title, name_ar, name_en, 'خطة استثمارية')
    INTO v_pct, v_min, v_max, v_active, v_dur, v_plan_title
    FROM public.investment_plans WHERE id = p_plan_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'الخطة غير موجودة');
    END IF;
    IF NOT v_active THEN
        RETURN json_build_object('success', false, 'error', 'الخطة غير مفعلة');
    END IF;
    IF p_amount < v_min THEN
        RETURN json_build_object('success', false, 'error', 'المبلغ أقل من الحد الأدنى: ' || v_min::TEXT);
    END IF;
    IF v_max IS NOT NULL AND p_amount > v_max THEN
        RETURN json_build_object('success', false, 'error', 'المبلغ يتجاوز الحد الأقصى: ' || v_max::TEXT);
    END IF;

    -- Wallet resolution: guaranteed non-null wallet_id
    SELECT id, available_balance, is_frozen INTO v_wid, v_bal, v_frozen
    FROM public.wallets
    WHERE user_id = v_user_id AND currency = 'USD'
    FOR UPDATE;

    IF v_wid IS NULL THEN
        v_wid := public.ensure_user_wallet(v_user_id);
        IF v_wid IS NULL THEN
            INSERT INTO public.wallets (user_id, currency, available_balance, profit_balance, invested_balance, pending_balance, is_frozen)
            VALUES (v_user_id, 'USD', 0, 0, 0, 0, false)
            ON CONFLICT (user_id, currency) DO UPDATE SET updated_at = NOW()
            RETURNING id INTO v_wid;
        END IF;
        SELECT available_balance, is_frozen INTO v_bal, v_frozen
        FROM public.wallets WHERE id = v_wid FOR UPDATE;
    END IF;

    IF v_wid IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'تعذر العثور على أو إنشاء محفظة المستخدم');
    END IF;

    IF COALESCE(v_frozen, false) THEN
        RETURN json_build_object('success', false, 'error', 'المحفظة مجمدة');
    END IF;
    IF COALESCE(v_bal, 0) < p_amount THEN
        RETURN json_build_object('success', false, 'error', 'الرصيد المتاح غير كافٍ');
    END IF;

    -- Authoritative Subscription Check (Never rely on stale profile tier alone)
    SELECT EXISTS (
        SELECT 1 FROM public.subscriptions
        WHERE user_id = v_user_id
          AND status = 'active'
          AND (COALESCE(expires_at, end_date) IS NULL OR COALESCE(expires_at, end_date) > NOW())
    ) INTO v_has_active_sub;

    -- Debit wallet (ONE-TIME principal transfer)
    UPDATE public.wallets
    SET available_balance = available_balance - p_amount,
        invested_balance = invested_balance + p_amount,
        updated_at = NOW()
    WHERE id = v_wid;

    -- Create transaction record
    v_txn := gen_random_uuid();
    INSERT INTO public.transactions (
        id, idempotency_key, user_id, wallet_id, type, amount, fee, currency, status,
        running_balance, description, processed_at, created_at, updated_at
    ) VALUES (
        v_txn, p_idempotency_key, v_user_id, v_wid, 'investment', p_amount, 0, 'USD', 'completed',
        (SELECT available_balance FROM public.wallets WHERE id = v_wid),
        'استثمار في ' || COALESCE(v_plan_title, 'خطة استثمارية'),
        NOW(), NOW(), NOW()
    );

    -- Create user investment record
    -- NON-SUBSCRIBED: status = 'not_active', next_payout_at = NULL, auto_restart_enabled = FALSE
    -- SUBSCRIBED: status = 'active', next_payout_at = NOW() + 24h, auto_restart_enabled = TRUE
    v_inv := gen_random_uuid();
    INSERT INTO public.user_investments (
        id, user_id, plan_id, transaction_id, amount, profit_percentage,
        expected_profit, start_date, end_date, next_payout_at, auto_restart_enabled,
        status, created_at, updated_at
    ) VALUES (
        v_inv, v_user_id, p_plan_id, v_txn, p_amount, v_pct, p_amount * v_pct / 100,
        CURRENT_TIMESTAMP,
        CASE WHEN v_dur IS NOT NULL THEN CURRENT_TIMESTAMP + (v_dur || ' days')::INTERVAL ELSE NULL END,
        CASE WHEN v_has_active_sub THEN CURRENT_TIMESTAMP + INTERVAL '24 hours' ELSE NULL END,
        v_has_active_sub,
        CASE WHEN v_has_active_sub THEN 'active' ELSE 'not_active' END,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    );

    RETURN json_build_object(
        'success', true,
        'message', 'تم إنشاء الاستثمار بنجاح',
        'investment_id', v_inv,
        'is_active', v_has_active_sub,
        'status', CASE WHEN v_has_active_sub THEN 'active' ELSE 'not_active' END
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ── 2. Overload wrappers for fn_create_investment & create_investment ────────
CREATE OR REPLACE FUNCTION public.fn_create_investment(
    p_plan_id uuid,
    p_amount numeric,
    p_idempotency_key text DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.fn_create_investment(auth.uid(), p_plan_id, p_amount, p_idempotency_key);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_investment(
    p_plan_id uuid,
    p_amount numeric,
    p_idempotency_key text DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.fn_create_investment(auth.uid(), p_plan_id, p_amount, p_idempotency_key);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_investment(
    p_user_id uuid,
    p_plan_id uuid,
    p_amount numeric,
    p_idempotency_key text DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.fn_create_investment(p_user_id, p_plan_id, p_amount, p_idempotency_key);
END;
$$;

-- ── 3. fn_start_next_cycle ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_start_next_cycle(p_investment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_inv RECORD;
    v_has_active_sub BOOLEAN := FALSE;
    v_next_payout TIMESTAMPTZ;
BEGIN
    -- 1. Authorization check
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- 2. Ownership & Row-lock check
    SELECT * INTO v_inv
    FROM public.user_investments
    WHERE id = p_investment_id AND user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Investment not found');
    END IF;

    -- 3. Terminal status check
    IF v_inv.status IN ('matured', 'completed', 'cancelled') THEN
        RETURN jsonb_build_object('success', false, 'error', 'الاستثمار غير مؤهل لبدء دورة جديدة');
    END IF;

    -- 4. Concurrency & Double-Click Guard:
    -- If a cycle is currently running in the future, reject immediately.
    IF v_inv.status = 'active' AND v_inv.next_payout_at IS NOT NULL AND v_inv.next_payout_at > NOW() THEN
        RETURN jsonb_build_object('success', false, 'error', 'دورة الاستثمار قيد التشغيل بالفعل');
    END IF;

    -- 5. Authoritative check on current subscription state
    SELECT EXISTS (
        SELECT 1 FROM public.subscriptions
        WHERE user_id = v_user_id
          AND status = 'active'
          AND (COALESCE(expires_at, end_date) IS NULL OR COALESCE(expires_at, end_date) > NOW())
    ) INTO v_has_active_sub;

    -- 6. Activate the 24-hour cycle
    -- ZERO wallet/balance deduction. Idempotent state transition.
    v_next_payout := NOW() + INTERVAL '24 hours';

    UPDATE public.user_investments
    SET status = 'active',
        next_payout_at = v_next_payout,
        auto_restart_enabled = v_has_active_sub,
        updated_at = NOW()
    WHERE id = p_investment_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'تم بدء دورة الاستثمار بنجاح',
        'investment_id', p_investment_id,
        'next_payout_at', v_next_payout,
        'auto_restart_enabled', v_has_active_sub
    );
END;
$$;

-- ── 4. fn_cron_distribute_daily_profits ──────────────────────────────────────
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

            -- Daily profit = expected_profit / duration_days
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

            -- Resolve wallet
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

            -- A. Credit wallet
            UPDATE public.wallets
            SET available_balance = available_balance + v_profit,
                profit_balance = profit_balance + v_profit,
                updated_at = v_now
            WHERE id = v_wallet_id;

            -- B. Insert profit transaction
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
                'investment_profit',
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

            -- C. Format profit
            v_profit_formatted := CASE
                WHEN v_profit = FLOOR(v_profit) THEN (v_profit::BIGINT)::TEXT
                WHEN v_profit = ROUND(v_profit, 2) THEN TO_CHAR(v_profit, 'FM999999990.00')
                ELSE RTRIM(RTRIM(TO_CHAR(v_profit, 'FM999999990.0000'), '0'), '.')
            END;

            -- D. Notification (exactly once per payout)
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

            -- E. Subscription-aware cycle handling (Authoritative check on public.subscriptions)
            SELECT EXISTS (
                SELECT 1 FROM public.subscriptions
                WHERE user_id = v_inv.user_id
                  AND status = 'active'
                  AND (COALESCE(expires_at, end_date) IS NULL OR COALESCE(expires_at, end_date) > v_now)
            ) INTO v_has_active_sub;

            v_should_auto_restart := v_has_active_sub AND v_inv.auto_restart_enabled;

            IF v_should_auto_restart THEN
                -- Subscribed: advance to next 24-hour cycle automatically
                UPDATE public.user_investments
                SET last_profit_at = v_now,
                    actual_profit = COALESCE(actual_profit, 0) + v_profit,
                    next_payout_at = GREATEST(v_now, v_inv.next_payout_at) + INTERVAL '24 hours',
                    updated_at = v_now
                WHERE id = v_inv.id;
            ELSE
                -- Non-subscribed / Unsubscribed: Return to 'not_active' waiting state
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

-- ── 5. fn_toggle_auto_restart ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_toggle_auto_restart(
    p_investment_id uuid,
    p_enabled boolean
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_has_active_sub BOOLEAN := FALSE;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- Authoritative check on public.subscriptions (never stale profile tier)
    SELECT EXISTS (
        SELECT 1 FROM public.subscriptions
        WHERE user_id = v_user_id
          AND status = 'active'
          AND (COALESCE(expires_at, end_date) IS NULL OR COALESCE(expires_at, end_date) > NOW())
    ) INTO v_has_active_sub;

    -- Non-subscribed users CANNOT enable auto_restart
    IF p_enabled AND NOT v_has_active_sub THEN
        RETURN jsonb_build_object('success', false, 'error', 'هذه الميزة متاحة فقط للمشتركين النشطين');
    END IF;

    UPDATE public.user_investments
    SET auto_restart_enabled = (p_enabled AND v_has_active_sub),
        updated_at = NOW()
    WHERE id = p_investment_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Investment not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'auto_restart_enabled', (p_enabled AND v_has_active_sub));
END;
$$;

-- ── 6. Grant Permissions ─────────────────────────────────────────────────────
ALTER FUNCTION public.fn_create_investment(uuid, uuid, numeric, text) OWNER TO postgres;
ALTER FUNCTION public.fn_create_investment(uuid, numeric, text) OWNER TO postgres;
ALTER FUNCTION public.create_investment(uuid, numeric, text) OWNER TO postgres;
ALTER FUNCTION public.create_investment(uuid, uuid, numeric, text) OWNER TO postgres;
ALTER FUNCTION public.fn_start_next_cycle(uuid) OWNER TO postgres;
ALTER FUNCTION public.fn_cron_distribute_daily_profits() OWNER TO postgres;
ALTER FUNCTION public.fn_toggle_auto_restart(uuid, boolean) OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.fn_create_investment(uuid, uuid, numeric, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_create_investment(uuid, numeric, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.create_investment(uuid, numeric, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.create_investment(uuid, uuid, numeric, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_start_next_cycle(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_cron_distribute_daily_profits() TO service_role, postgres;
GRANT EXECUTE ON FUNCTION public.fn_toggle_auto_restart(uuid, boolean) TO authenticated, service_role;
