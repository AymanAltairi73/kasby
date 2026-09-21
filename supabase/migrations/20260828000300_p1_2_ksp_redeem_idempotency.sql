-- ==============================================================================
-- KASBY P1-2 : KSP REDEMPTION IDEMPOTENCY (Option C / Variant B1)
-- ==============================================================================
-- Scope (STRICT P1-2 ONLY):
--   Makes KSP redemption retry-safe WITHOUT changing any financial behavior.
--   Target: fn_redeem_ksp_to_wallet
--   Database-level idempotency via the EXISTING financial_idempotency_keys
--   mechanism (UNIQUE(user_id, idempotency_key, operation_type)), using
--   operation_type = 'ksp_redemption'.
--
-- It does NOT:
--   * Change 1000 KSP = $1 USD, KSP deduction, USD credit, wallet/KSP/effective
--     semantics, transaction amount/type, notification, authorization,
--     validation, or row-locking behavior.
--   * Add/alter any UNIQUE constraint on transactions.idempotency_key (B2 is
--     NOT in scope).
--   * Modify, scan, delete, or clean any historical transaction records.
--   * Touch Transfer, Withdrawal, Deposit, Investment, Store, Daily Profit,
--     Loans, Agent Commission, Notifications, FCM, or Realtime.
--
-- Atomicity:
--   The idempotency reservation is made BEFORE any financial mutation, and the
--   reservation + financial effect + result payload are committed in ONE
--   transaction. A concurrent request with the SAME idempotency key either:
--     * blocks on the unique index until the first transaction commits, then
--       returns the stored result (NO second financial effect), or
--     * if the first transaction rolls back, proceeds as the first claim.
--   Exactly one financial effect per logical operation.
--
-- Reversible: DROP + re-create the prior function body on rollback. No data
--   changes are performed by this migration (it only (re)defines a function).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1) Rewrite fn_redeem_ksp_to_wallet with atomic, reserve-before-move idempotency.
--    All financial lines are preserved verbatim from the current production body;
--    only the idempotency mechanism is changed (and strengthened).
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_redeem_ksp_to_wallet(
    p_ksp_amount INT,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_wallet_id UUID;
    v_reward_ksp_current INT;
    v_wallet_usd_current NUMERIC;
    v_usd_credit NUMERIC;
    v_new_reward_ksp INT;
    v_new_wallet_usd NUMERIC;
    v_new_wallet_ksp INT;
    v_new_effective_ksp INT;
    v_claimed_id UUID;
    v_existing_payload JSONB;
    v_result JSONB;
    v_use_key TEXT := COALESCE(NULLIF(p_idempotency_key, ''), NULL);
BEGIN
    -- 1. Verify Authentication (unchanged)
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'UNAUTHORIZED'
        );
    END IF;

    -- 2. Validate request (unchanged)
    IF p_ksp_amount IS NULL OR p_ksp_amount < 1000 OR (p_ksp_amount % 1000) != 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'INVALID_KSP_AMOUNT_MUST_BE_MULTIPLE_OF_1000'
        );
    END IF;

    -- 3. Atomically reserve/claim the idempotency key BEFORE any financial
    --    mutation. Uses the EXISTING financial_idempotency_keys UNIQUE
    --    (user_id, idempotency_key, operation_type) guard.
    IF v_use_key IS NOT NULL THEN
        INSERT INTO public.financial_idempotency_keys (
            user_id, idempotency_key, operation_type, result_payload
        )
        VALUES (
            v_user_id, v_use_key, 'ksp_redemption', '{}'::jsonb
        )
        ON CONFLICT (user_id, idempotency_key, operation_type) DO NOTHING
        RETURNING id INTO v_claimed_id;

        -- 4. Key already exists -> someone has claimed or completed it.
        IF v_claimed_id IS NULL THEN
            SELECT result_payload INTO v_existing_payload
            FROM public.financial_idempotency_keys
            WHERE user_id = v_user_id
              AND idempotency_key = v_use_key
              AND operation_type = 'ksp_redemption';

            -- If the previous attempt recorded a real result, return it as-is
            -- (already processed or previously failed) WITHOUT any mutation.
            IF v_existing_payload IS NOT NULL
               AND v_existing_payload <> '{}'::jsonb THEN
                RETURN v_existing_payload;
            END IF;

            -- No committed result yet (first attempt in-flight/rolled-back,
            -- or a stale empty claim). Do not issue a second financial effect.
            RETURN jsonb_build_object(
                'success', false,
                'error', 'KSP_REDEMPTION_IN_PROGRESS',
                'idempotent', true
            );
        END IF;
    END IF;

    -- 5. Lock & Verify User Points (Reward KSP) -- UNCHANGED
    SELECT current_balance INTO v_reward_ksp_current
    FROM public.user_points
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        -- Insufficient/absent points profile: record failure on the key if it
        -- was claimed, then return, all atomically (no financial mutation).
        IF v_use_key IS NOT NULL THEN
            UPDATE public.financial_idempotency_keys
            SET result_payload = jsonb_build_object(
                    'success', false,
                    'error', 'User points profile not found'
                )
            WHERE user_id = v_user_id
              AND idempotency_key = v_use_key
              AND operation_type = 'ksp_redemption';
        END IF;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User points profile not found'
        );
    END IF;

    IF v_reward_ksp_current < p_ksp_amount THEN
        IF v_use_key IS NOT NULL THEN
            UPDATE public.financial_idempotency_keys
            SET result_payload = jsonb_build_object(
                    'success', false,
                    'error', 'Insufficient KSP balance'
                )
            WHERE user_id = v_user_id
              AND idempotency_key = v_use_key
              AND operation_type = 'ksp_redemption';
        END IF;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient KSP balance'
        );
    END IF;

    -- 5b. Lock & Verify Wallet -- UNCHANGED
    SELECT id, available_balance INTO v_wallet_id, v_wallet_usd_current
    FROM public.wallets
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        IF v_use_key IS NOT NULL THEN
            UPDATE public.financial_idempotency_keys
            SET result_payload = jsonb_build_object(
                    'success', false,
                    'error', 'User wallet not found'
                )
            WHERE user_id = v_user_id
              AND idempotency_key = v_use_key
              AND operation_type = 'ksp_redemption';
        END IF;
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User wallet not found'
        );
    END IF;

    -- 6. Calculate USD Credit (1,000 KSP = $1.00 USD) -- UNCHANGED
    v_usd_credit := (p_ksp_amount::numeric / 1000.0);

    -- 7. Deduct Reward KSP -- UNCHANGED
    UPDATE public.user_points
    SET current_balance = current_balance - p_ksp_amount,
        total_spent = COALESCE(total_spent, 0) + p_ksp_amount,
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING current_balance INTO v_new_reward_ksp;

    -- 8. Credit Wallet USD -- UNCHANGED
    UPDATE public.wallets
    SET available_balance = available_balance + v_usd_credit,
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING available_balance INTO v_new_wallet_usd;

    -- 9. Record Completed Transaction -- UNCHANGED
    INSERT INTO public.transactions (
        idempotency_key,
        user_id,
        wallet_id,
        type,
        amount,
        fee,
        currency,
        status,
        description,
        created_at
    ) VALUES (
        v_use_key,
        v_user_id,
        v_wallet_id,
        'ksp_redemption',
        v_usd_credit,
        0.00,
        'USD',
        'completed',
        'تحويل ' || p_ksp_amount || ' KSP إلى رصيد كاش ($' || TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM v_usd_credit::text)) || ' USD)',
        NOW()
    );

    -- 10. Record User Notification -- UNCHANGED
    INSERT INTO public.notifications (
        user_id,
        title,
        message,
        type,
        category,
        status,
        role_target,
        created_at
    ) VALUES (
        v_user_id,
        'تحويل نقاط KSP بنجاح',
        'تم تحويل ' || p_ksp_amount || ' KSP وإضافة $' || TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM v_usd_credit::text)) || ' USD إلى رصيدك النقدي.',
        'notification',
        'system',
        'sent',
        'user',
        NOW()
    );

    -- 11. Calculate Unified Balances -- UNCHANGED
    v_new_wallet_ksp := FLOOR(COALESCE(v_new_wallet_usd, 0) * 1000);
    v_new_effective_ksp := COALESCE(v_new_reward_ksp, 0) + v_new_wallet_ksp;

    -- 12. Build success result -- UNCHANGED shape
    v_result := jsonb_build_object(
        'success', true,
        'redeemed_ksp', p_ksp_amount,
        'usd_credited', v_usd_credit,
        'reward_ksp', v_new_reward_ksp,
        'wallet_usd', v_new_wallet_usd,
        'wallet_ksp', v_new_wallet_ksp,
        'effective_ksp', v_new_effective_ksp
    );

    -- 13. Mark the operation successful (idempotent recall) -- atomically.
    IF v_use_key IS NOT NULL THEN
        UPDATE public.financial_idempotency_keys
        SET result_payload = v_result
        WHERE user_id = v_user_id
          AND idempotency_key = v_use_key
          AND operation_type = 'ksp_redemption';
    END IF;

    RETURN v_result;
END;
$$;

-- ------------------------------------------------------------------------------
-- 2) Preserve grants exactly as before (authenticated + service_role).
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.fn_redeem_ksp_to_wallet(INT, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- No other objects changed. No B2 (no unique on transactions.idempotency_key).
-- No historical data touched.
-- ==============================================================================
