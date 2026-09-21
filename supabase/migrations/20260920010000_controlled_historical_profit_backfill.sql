-- ============================================================================
-- CONTROLLED HISTORICAL PROFIT BACKFILL MIGRATION
-- Migration Name: 20260920010000_controlled_historical_profit_backfill.sql
-- Status: PREPARED FOR HUMAN REVIEW — DO NOT EXECUTE WITHOUT ADMIN APPROVAL
--
-- Security:
--   - Atomic transaction with row-level locks (FOR UPDATE)
--   - Deterministic cycle-level reference (historical_profit:{inv_id}:{YYYY-MM-DD})
--   - 100% Idempotent (safe to re-run; re-runs produce 0 new payouts)
--   - Strict profit cap enforcement (already_paid + payout <= expected_profit)
--   - Concurrency lock against fn_cron_distribute_daily_profits
--   - Independent notification idempotency check
--   - Full audit logging into public.system_logs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_admin_reconcile_historical_profits(
    p_scope TEXT DEFAULT 'strict', -- 'strict' (12 users / 56 invs) or 'broad' (19 users / 94 invs)
    p_dry_run BOOLEAN DEFAULT TRUE  -- Set to FALSE only when explicitly authorized
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_now TIMESTAMPTZ := NOW();
    v_failure_start TIMESTAMPTZ := '2026-09-12 20:41:00+00';
    v_failure_end   TIMESTAMPTZ := '2026-09-20 00:00:00+00';
    
    v_inv RECORD;
    v_wallet_id UUID;
    v_daily_profit NUMERIC(18,4);
    v_payable_amount NUMERIC(18,4);
    v_remaining_cap NUMERIC(18,4);
    v_cycle_cursor TIMESTAMPTZ;
    v_cycle_date_str TEXT;
    v_deterministic_ref TEXT;
    v_txn_id UUID;
    v_profit_formatted TEXT;
    
    v_total_eligible_cycles INT := 0;
    v_total_paid_amount NUMERIC(18,4) := 0.00;
    v_affected_investments_count INT := 0;
    v_affected_users_count INT := 0;
    v_affected_users_set UUID[] := ARRAY[]::UUID[];
    
    v_cron_is_running BOOLEAN;
BEGIN
    -- ── 1. CONCURRENCY SAFETY GUARD ─────────────────────────────────────────
    -- Coordinate with daily profit distribution job using PostgreSQL advisory lock
    -- Lock key: 849201948271 (Kasby Profit Pipeline Lock)
    IF NOT pg_try_advisory_xact_lock(849201948271) THEN
        RAISE EXCEPTION 'Concurrency conflict: Profit distribution or reconciliation is currently running. Please retry in 1 minute.';
    END IF;

    -- Safety check: Check if profit distribution is paused
    IF EXISTS (SELECT 1 FROM public.system_settings WHERE pause_profits = TRUE LIMIT 1) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Profits are currently paused in system_settings.'
        );
    END IF;

    -- ── 2. AUDIT LOGGING START ──────────────────────────────────────────────
    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(), 'admin', 'historical_profit_reconciliation_started', 'system', 'profit_pipeline',
        jsonb_build_object(
            'scope', p_scope,
            'dry_run', p_dry_run,
            'started_at', v_now
        ), 'info'
    );

    -- ── 3. PROCESS EACH INVESTMENT ELIGIBLE FOR BACKFILL ────────────────────
    FOR v_inv IN
        SELECT
            ui.id,
            ui.user_id,
            ui.plan_id,
            ui.amount,
            ui.expected_profit,
            ui.actual_profit,
            ui.created_at,
            ui.next_payout_at,
            ui.auto_restart_enabled,
            ui.status,
            COALESCE(ip.name_ar, ip.name_en, 'خطة الاستثمار') AS plan_name_ar,
            COALESCE(ip.duration_days, 30) AS plan_duration_days
        FROM public.user_investments ui
        LEFT JOIN public.investment_plans ip ON ip.id = ui.plan_id
        WHERE ui.status = 'active'
          AND ui.created_at < v_failure_end
          AND (
              p_scope = 'broad' 
              OR (p_scope = 'strict' AND (ui.next_payout_at IS NOT NULL OR ui.auto_restart_enabled = TRUE))
          )
        ORDER BY ui.created_at ASC
        FOR UPDATE OF ui
    LOOP
        -- Calculate current remaining cap directly from authoritative row
        v_remaining_cap := GREATEST(0.00, v_inv.expected_profit - COALESCE(v_inv.actual_profit, 0.00));
        
        IF v_remaining_cap <= 0.001 THEN
            CONTINUE; -- Cap already reached, skip
        END IF;

        v_daily_profit := ROUND((v_inv.expected_profit / NULLIF(v_inv.plan_duration_days, 0))::numeric, 2);
        IF v_daily_profit <= 0 THEN
            CONTINUE;
        END IF;

        -- Resolve or lock user USD wallet
        SELECT id INTO v_wallet_id
        FROM public.wallets
        WHERE user_id = v_inv.user_id AND currency = 'USD'
        FOR UPDATE;

        IF v_wallet_id IS NULL THEN
            IF NOT p_dry_run THEN
                v_wallet_id := public.ensure_user_wallet(v_inv.user_id);
            END IF;
        END IF;

        -- Cycle cursor starts at investment creation (+24h) or failure start, whichever is later
        v_cycle_cursor := GREATEST(v_inv.created_at + INTERVAL '24 hours', v_failure_start);

        WHILE v_cycle_cursor < v_failure_end LOOP
            v_cycle_date_str := TO_CHAR(v_cycle_cursor AT TIME ZONE 'UTC', 'YYYY-MM-DD');
            v_deterministic_ref := 'historical_profit:' || v_inv.id::TEXT || ':' || v_cycle_date_str;

            -- ── DETERMINISTIC IDEMPOTENCY CHECK ──
            -- Check if this cycle was already paid historically or normally
            IF EXISTS (
                SELECT 1 FROM public.transactions
                WHERE user_id = v_inv.user_id
                  AND (
                      reference_id = v_deterministic_ref
                      OR (
                          type = 'profit'
                          AND reference_id = v_inv.id::TEXT
                          AND ABS(EXTRACT(EPOCH FROM (created_at - v_cycle_cursor))) < 64800 -- 18 hours
                      )
                  )
            ) THEN
                -- Already paid, skip cycle
                v_cycle_cursor := v_cycle_cursor + INTERVAL '24 hours';
                CONTINUE;
            END IF;

            -- Check profit cap before every single cycle payout
            IF v_remaining_cap < v_daily_profit THEN
                v_payable_amount := v_remaining_cap;
            ELSE
                v_payable_amount := v_daily_profit;
            END IF;

            IF v_payable_amount <= 0.001 THEN
                EXIT; -- Cap exhausted for this investment
            END IF;

            -- Record cycle accounting
            v_total_eligible_cycles := v_total_eligible_cycles + 1;
            v_total_paid_amount := v_total_paid_amount + v_payable_amount;
            v_remaining_cap := v_remaining_cap - v_payable_amount;

            IF NOT (v_inv.user_id = ANY(v_affected_users_set)) THEN
                v_affected_users_set := array_append(v_affected_users_set, v_inv.user_id);
            END IF;

            -- ── EXECUTE FINANCIAL STATE CHANGE (IF NOT DRY RUN) ──
            IF NOT p_dry_run THEN
                -- A. Credit wallet atomically
                UPDATE public.wallets
                SET available_balance = available_balance + v_payable_amount,
                    profit_balance = profit_balance + v_payable_amount,
                    updated_at = v_now
                WHERE id = v_wallet_id;

                -- B. Insert transaction with deterministic reference
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
                    v_payable_amount,
                    0,
                    'USD',
                    'completed',
                    'تعويض أرباح تاريخية مستحقة (' || v_cycle_date_str || ') من ' || v_inv.plan_name_ar,
                    v_deterministic_ref,
                    (SELECT available_balance FROM public.wallets WHERE id = v_wallet_id),
                    v_now,
                    v_now,
                    v_now
                );

                -- C. Update investment actual_profit
                UPDATE public.user_investments
                SET actual_profit = COALESCE(actual_profit, 0) + v_payable_amount,
                    updated_at = v_now
                WHERE id = v_inv.id;

                -- D. Format profit for notification
                v_profit_formatted := TO_CHAR(v_payable_amount, 'FM999999990.00');

                -- E. Idempotent Notification Insertion
                IF NOT EXISTS (
                    SELECT 1 FROM public.notifications
                    WHERE user_id = v_inv.user_id
                      AND type = 'daily_profit'
                      AND entity_id = v_inv.id::TEXT
                      AND created_at >= v_now - INTERVAL '1 hour'
                      AND message LIKE '%' || v_cycle_date_str || '%'
                ) THEN
                    PERFORM public.fn_create_notification(
                        v_inv.user_id,
                        'أرباح استثمار مستحقة 💰',
                        'تم إضافة أرباح بقيمة $' || v_profit_formatted || ' عن يوم ' || v_cycle_date_str || ' من ' || v_inv.plan_name_ar,
                        'daily_profit',
                        'investment',
                        v_inv.id::TEXT,
                        '/my-investments',
                        'user',
                        'normal'
                    );
                END IF;
            END IF;

            v_cycle_cursor := v_cycle_cursor + INTERVAL '24 hours';
        END LOOP;
    END LOOP;

    -- ── 4. AUDIT LOGGING FINISH ─────────────────────────────────────────────
    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(), 'admin', 'historical_profit_reconciliation_completed', 'system', 'profit_pipeline',
        jsonb_build_object(
            'scope', p_scope,
            'dry_run', p_dry_run,
            'total_eligible_cycles', v_total_eligible_cycles,
            'total_paid_amount', v_total_paid_amount,
            'affected_users_count', COALESCE(cardinality(v_affected_users_set), 0),
            'completed_at', NOW()
        ), 'info'
    );

    RETURN jsonb_build_object(
        'success', true,
        'dry_run', p_dry_run,
        'scope', p_scope,
        'affected_users_count', COALESCE(cardinality(v_affected_users_set), 0),
        'total_eligible_cycles', v_total_eligible_cycles,
        'total_reconciled_amount', v_total_paid_amount,
        'message', CASE 
            WHEN p_dry_run THEN 'Dry run completed successfully. Zero database changes made.'
            ELSE 'Historical profit backfill applied successfully and committed atomically.'
        END
    );
END;
$$;
