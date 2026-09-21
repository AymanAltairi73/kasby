-- ============================================================
-- Migration: Add Notifications to Daily Profit Distribution
-- ============================================================

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

                -- Insert In-App Notification for profit received
                INSERT INTO public.notifications (
                    user_id,
                    title,
                    title_ar,
                    message,
                    message_ar,
                    type,
                    metadata,
                    created_at
                ) VALUES (
                    v_inv.user_id,
                    'Daily Profit Received 💰',
                    'أرباح جديدة 💰',
                    'You received $' || ROUND(v_profit, 2)::TEXT || ' daily profit.',
                    'تم إيداع مبلغ $' || ROUND(v_profit, 2)::TEXT || ' كأرباح يومية في محفظتك بنجاح.',
                    'daily_profit',
                    jsonb_build_object('investment_id', v_inv.id, 'amount', v_profit),
                    NOW()
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

                -- Insert In-App Notification for investment maturity
                INSERT INTO public.notifications (
                    user_id,
                    title,
                    title_ar,
                    message,
                    message_ar,
                    type,
                    metadata,
                    created_at
                ) VALUES (
                    v_inv.user_id,
                    'Investment Matured 🎉',
                    'اكتمل الاستثمار 🎉',
                    'Your investment has matured and $' || ROUND(v_inv.amount, 2)::TEXT || ' principal was returned to your wallet.',
                    'اكتملت مدة استثمارك وتم إرجاع رأس المال بمبلغ $' || ROUND(v_inv.amount, 2)::TEXT || ' إلى محفظتك بنجاح.',
                    'investment_matured',
                    jsonb_build_object('investment_id', v_inv.id, 'amount', v_inv.amount),
                    NOW()
                );
            END IF;
        END IF;

    END LOOP;
END;
$$;
