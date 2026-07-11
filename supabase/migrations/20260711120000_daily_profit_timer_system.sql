-- ============================================================
-- Daily Profit Timer & Auto-Restart System Migration
-- ============================================================

-- 1. Schema Additions
ALTER TABLE public.user_investments
  ADD COLUMN IF NOT EXISTS next_payout_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS auto_restart_enabled BOOLEAN DEFAULT FALSE;

-- 2. Backfill existing active investments
-- Any active investment should have next_payout_at set to 24h after their last profit distribution (or start date if none yet)
UPDATE public.user_investments
SET next_payout_at = COALESCE(last_profit_at, start_date) + INTERVAL '24 hours'
WHERE status = 'active' AND next_payout_at IS NULL;

-- 3. Auto-enable auto_restart for existing Premium/VIP users
UPDATE public.user_investments ui
SET auto_restart_enabled = TRUE
FROM public.profiles p
WHERE p.id = ui.user_id
  AND p.account_tier IN ('premium', 'vip')
  AND ui.status = 'active';

-- 4. Update create_investment RPC to initialize next_payout_at and auto_restart_enabled
CREATE OR REPLACE FUNCTION "public"."fn_create_investment"("p_user_id" "uuid", "p_plan_id" "uuid", "p_amount" numeric, "p_idempotency_key" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_wid UUID; v_bal NUMERIC(18,4); v_pct NUMERIC(6,3);
    v_min NUMERIC(18,4); v_max NUMERIC(18,4); v_active BOOLEAN;
    v_dur INTEGER; v_txn UUID; v_inv UUID; v_frozen BOOLEAN;
    v_is_premium BOOLEAN;
BEGIN
    SELECT profit_percentage, min_amount, max_amount, is_active, duration_days
    INTO v_pct, v_min, v_max, v_active, v_dur
    FROM investment_plans WHERE id = p_plan_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Plan not found.'; END IF;
    IF NOT v_active THEN RAISE EXCEPTION 'Plan inactive.'; END IF;
    IF p_amount < v_min THEN RAISE EXCEPTION 'Below minimum: %', v_min; END IF;
    IF v_max IS NOT NULL AND p_amount > v_max THEN RAISE EXCEPTION 'Exceeds maximum: %', v_max; END IF;
    IF EXISTS (SELECT 1 FROM system_settings WHERE pause_investments = TRUE LIMIT 1) THEN
        RAISE EXCEPTION 'Investments paused.'; END IF;

    SELECT id, available_balance, is_frozen INTO v_wid, v_bal, v_frozen
    FROM wallets WHERE user_id = p_user_id FOR UPDATE;
    IF v_frozen THEN RAISE EXCEPTION 'Wallet frozen.'; END IF;
    IF v_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance: %, Requested: %', v_bal, p_amount; END IF;

    -- Check if user is premium/vip
    SELECT account_tier IN ('premium', 'vip') INTO v_is_premium
    FROM profiles WHERE id = p_user_id;

    UPDATE wallets SET available_balance = available_balance - p_amount,
        invested_balance = invested_balance + p_amount WHERE id = v_wid;

    v_txn := uuid_generate_v4();
    INSERT INTO transactions (id, idempotency_key, user_id, wallet_id, type, amount, currency, status, running_balance)
    VALUES (v_txn, p_idempotency_key, p_user_id, v_wid, 'investment', p_amount, 'USD', 'completed',
            (SELECT available_balance FROM wallets WHERE id = v_wid));

    v_inv := uuid_generate_v4();
    INSERT INTO user_investments (
        id, user_id, plan_id, transaction_id, amount, profit_percentage, 
        expected_profit, start_date, end_date, next_payout_at, auto_restart_enabled
    )
    VALUES (
        v_inv, p_user_id, p_plan_id, v_txn, p_amount, v_pct, p_amount * v_pct / 100,
        CURRENT_TIMESTAMP,
        CASE WHEN v_dur IS NOT NULL THEN CURRENT_TIMESTAMP + (v_dur || ' days')::INTERVAL ELSE NULL END,
        CURRENT_TIMESTAMP + INTERVAL '24 hours', -- Initialize first cycle
        COALESCE(v_is_premium, FALSE)
    );

    RETURN v_inv;
END;
$$;

-- 5. Update fn_cron_distribute_daily_profits to check next_payout_at and control cycle restart
CREATE OR REPLACE FUNCTION "public"."fn_cron_distribute_daily_profits"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_inv RECORD;
    v_profit NUMERIC(18,4);
    v_wallet_id UUID;
    v_is_premium BOOLEAN;
BEGIN
    -- Check if profits are paused
    IF EXISTS (SELECT 1 FROM public.system_settings WHERE pause_profits = TRUE LIMIT 1) THEN
        RETURN;
    END IF;

    FOR v_inv IN
        SELECT id, user_id, amount, profit_percentage, end_date,
               last_profit_at, is_collateral_locked, next_payout_at, auto_restart_enabled
        FROM public.user_investments
        WHERE status = 'active'
          AND next_payout_at IS NOT NULL
          AND NOW() >= next_payout_at
        FOR UPDATE SKIP LOCKED
    LOOP
        -- Calculate daily profit
        v_profit := ROUND((v_inv.amount * (v_inv.profit_percentage / 100) / 365), 4);

        IF v_profit > 0 THEN
            SELECT id INTO v_wallet_id
            FROM public.wallets WHERE user_id = v_inv.user_id
            FOR UPDATE;

            IF v_wallet_id IS NOT NULL THEN
                UPDATE public.wallets
                SET available_balance = available_balance + v_profit,
                    profit_balance = profit_balance + v_profit,
                    updated_at = NOW()
                WHERE id = v_wallet_id;

                INSERT INTO public.transactions (
                    user_id, wallet_id, type, amount, status, description, running_balance
                ) VALUES (
                    v_inv.user_id, v_wallet_id, 'profit', v_profit, 'completed',
                    'Daily profit distribution',
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id)
                );
            END IF;
        END IF;

        -- Check if user is premium/vip
        SELECT account_tier IN ('premium', 'vip') INTO v_is_premium
        FROM profiles WHERE id = v_inv.user_id;

        -- Update investment cycle and payout history
        UPDATE public.user_investments
        SET last_profit_at = NOW(),
            actual_profit = COALESCE(actual_profit, 0) + v_profit,
            next_payout_at = CASE 
                WHEN (v_is_premium OR v_inv.auto_restart_enabled) THEN v_inv.next_payout_at + INTERVAL '24 hours'
                ELSE NULL -- Stops cycle for Standard users
            END
        WHERE id = v_inv.id;

        -- Maturity checks (collateral lock aware)
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
                    'Investment matured — principal returned',
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id)
                );
            END IF;
        END IF;

    END LOOP;
END;
$$;

-- 6. Add RPC fn_start_next_cycle for Standard users
CREATE OR REPLACE FUNCTION "public"."fn_start_next_cycle"("p_investment_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_inv RECORD;
BEGIN
    SELECT * INTO v_inv
    FROM user_investments
    WHERE id = p_investment_id AND user_id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Investment not found');
    END IF;

    IF v_inv.status != 'active' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Investment is not active');
    END IF;

    IF v_inv.next_payout_at IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cycle is already running');
    END IF;

    UPDATE user_investments
    SET next_payout_at = NOW() + INTERVAL '24 hours'
    WHERE id = p_investment_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 7. Add RPC fn_toggle_auto_restart for Premium users
CREATE OR REPLACE FUNCTION "public"."fn_toggle_auto_restart"("p_investment_id" "uuid", "p_enabled" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_premium BOOLEAN;
BEGIN
    SELECT account_tier IN ('premium', 'vip') INTO v_is_premium
    FROM profiles WHERE id = v_user_id;

    IF NOT COALESCE(v_is_premium, FALSE) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Feature available for Premium users only');
    END IF;

    UPDATE user_investments
    SET auto_restart_enabled = p_enabled
    WHERE id = p_investment_id AND user_id = v_user_id;

    RETURN jsonb_build_object('success', true);
END;
$$;
