-- ============================================================
-- Migration: Repair create_investment wallet crash + subscriptions schema
-- Date: 2026-09-11
--
-- Root Cause & Permanent Fix:
--   1. Subscriptions schema drift:
--      fn_cron_distribute_daily_profits checks expires_at on subscriptions,
--      which was missing on older databases.
--      -> Ensure expires_at column exists and is backfilled.
--   2. create_investment & fn_create_investment NOT NULL wallet_id violation:
--      Legacy create_investment function on Supabase inserted NULL for wallet_id
--      into the transactions table, violating the NOT NULL constraint.
--      The previous fix defined only fn_create_investment (with uuid_generate_v4()
--      which does not exist in search_path=public), whereas Flutter calls create_investment.
--      -> Unify and harden BOTH create_investment and fn_create_investment:
--         - Use built-in gen_random_uuid() instead of uuid_generate_v4().
--         - Guaranteed wallet resolution (USD lookup -> ensure_user_wallet -> fallback create).
--         - Support both 3-arg and 4-arg signatures for both function names.
--         - Idempotency guard and atomic balance updates.
-- ============================================================

BEGIN;

-- ── 1. subscriptions schema: add expires_at (drift fix) ───────────────
ALTER TABLE public.subscriptions
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

UPDATE public.subscriptions
SET expires_at = COALESCE(end_date, start_date + INTERVAL '30 days')
WHERE expires_at IS NULL
  AND status = 'active';

-- ── 2. Drop existing variants to avoid signature conflicts ────────────
DROP FUNCTION IF EXISTS public.fn_create_investment(uuid, uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.fn_create_investment(uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.create_investment(uuid, uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.create_investment(uuid, numeric, text) CASCADE;

-- ── 3. Master implementation: fn_create_investment(p_user_id, p_plan_id, p_amount, p_idempotency_key) ──
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
    v_is_premium BOOLEAN;
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
            -- Direct creation fallback if ensure_user_wallet failed
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

    -- Premium/VIP check for auto-restart
    SELECT account_tier IN ('premium', 'vip') INTO v_is_premium
    FROM public.profiles WHERE id = v_user_id;

    -- Debit wallet
    UPDATE public.wallets
    SET available_balance = available_balance - p_amount,
        invested_balance = invested_balance + p_amount,
        updated_at = NOW()
    WHERE id = v_wid;

    -- Create transaction (wallet_id is guaranteed non-null, uses gen_random_uuid)
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
    v_inv := gen_random_uuid();
    INSERT INTO public.user_investments (
        id, user_id, plan_id, transaction_id, amount, profit_percentage,
        expected_profit, start_date, end_date, next_payout_at, auto_restart_enabled,
        status, created_at, updated_at
    ) VALUES (
        v_inv, v_user_id, p_plan_id, v_txn, p_amount, v_pct, p_amount * v_pct / 100,
        CURRENT_TIMESTAMP,
        CASE WHEN v_dur IS NOT NULL THEN CURRENT_TIMESTAMP + (v_dur || ' days')::INTERVAL ELSE NULL END,
        CURRENT_TIMESTAMP + INTERVAL '24 hours',
        COALESCE(v_is_premium, FALSE),
        'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    );

    RETURN json_build_object(
        'success', true,
        'message', 'تم إنشاء الاستثمار بنجاح',
        'investment_id', v_inv
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ── 4. 3-arg overload: fn_create_investment(p_plan_id, p_amount, p_idempotency_key) ──
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

-- ── 5. Primary create_investment alias: create_investment(p_plan_id, p_amount, p_idempotency_key) ──
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

-- ── 6. 4-arg alias: create_investment(p_user_id, p_plan_id, p_amount, p_idempotency_key) ──
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

-- ── 7. Ownership and Permissions ──
ALTER FUNCTION public.fn_create_investment(uuid, uuid, numeric, text) OWNER TO postgres;
ALTER FUNCTION public.fn_create_investment(uuid, numeric, text) OWNER TO postgres;
ALTER FUNCTION public.create_investment(uuid, numeric, text) OWNER TO postgres;
ALTER FUNCTION public.create_investment(uuid, uuid, numeric, text) OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.fn_create_investment(uuid, uuid, numeric, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.fn_create_investment(uuid, numeric, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.create_investment(uuid, numeric, text) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION public.create_investment(uuid, uuid, numeric, text) TO authenticated, service_role, anon;

COMMIT;