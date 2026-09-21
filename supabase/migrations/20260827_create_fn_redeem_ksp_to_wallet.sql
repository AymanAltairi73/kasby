-- =============================================================================
-- Migration: Create fn_redeem_ksp_to_wallet RPC (WITH NOTIFICATION)
-- Description: Converts reward KSP points into liquid USD wallet cash and notifies user.
-- Ratio: 1,000 KSP = $1.00 USD
-- Security: SECURITY DEFINER, strict auth check, row locking (FOR UPDATE)
-- =============================================================================

-- 1. Drop existing constraint and recreate with ALL existing database types + 'ksp_redemption'
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check 
CHECK (type IN (
    'admin_credit',
    'admin_debit',
    'deposit',
    'fee',
    'investment',
    'investment_return',
    'ksp_redemption',
    'loan_disbursement',
    'loan_repayment',
    'marketplace_purchase',
    'profit',
    'reward',
    'reward_redemption',
    'transfer_in',
    'transfer_out',
    'withdrawal'
));

-- 2. Create/Replace fn_redeem_ksp_to_wallet RPC
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
    v_existing_tx RECORD;
BEGIN
    -- 1. Verify Authentication
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'UNAUTHORIZED'
        );
    END IF;

    -- 2. Validate KSP amount (minimum 1,000 & multiple of 1,000)
    IF p_ksp_amount IS NULL OR p_ksp_amount < 1000 OR (p_ksp_amount % 1000) != 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'INVALID_KSP_AMOUNT_MUST_BE_MULTIPLE_OF_1000'
        );
    END IF;

    -- 3. Idempotency Guard (Prevents double-redemption on network retry)
    IF p_idempotency_key IS NOT NULL AND p_idempotency_key != '' THEN
        SELECT id, status, amount INTO v_existing_tx
        FROM public.transactions
        WHERE idempotency_key = p_idempotency_key AND user_id = v_user_id
        LIMIT 1;

        IF FOUND THEN
            SELECT available_balance INTO v_new_wallet_usd FROM public.wallets WHERE user_id = v_user_id;
            SELECT current_balance INTO v_new_reward_ksp FROM public.user_points WHERE user_id = v_user_id;
            
            v_new_wallet_ksp := FLOOR(COALESCE(v_new_wallet_usd, 0) * 1000);
            v_new_effective_ksp := COALESCE(v_new_reward_ksp, 0) + v_new_wallet_ksp;

            RETURN jsonb_build_object(
                'success', true,
                'idempotent', true,
                'message', 'ALREADY_PROCESSED',
                'redeemed_ksp', p_ksp_amount,
                'usd_credited', v_existing_tx.amount,
                'reward_ksp', v_new_reward_ksp,
                'wallet_usd', v_new_wallet_usd,
                'wallet_ksp', v_new_wallet_ksp,
                'effective_ksp', v_new_effective_ksp
            );
        END IF;
    END IF;

    -- 4. Lock & Verify User Points (Reward KSP)
    SELECT current_balance INTO v_reward_ksp_current
    FROM public.user_points
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User points profile not found'
        );
    END IF;

    IF v_reward_ksp_current < p_ksp_amount THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Insufficient KSP balance'
        );
    END IF;

    -- 5. Lock & Verify Wallet
    SELECT id, available_balance INTO v_wallet_id, v_wallet_usd_current
    FROM public.wallets
    WHERE user_id = v_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'User wallet not found'
        );
    END IF;

    -- 6. Calculate USD Credit (1,000 KSP = $1.00 USD)
    v_usd_credit := (p_ksp_amount::numeric / 1000.0);

    -- 7. Deduct Reward KSP
    UPDATE public.user_points
    SET current_balance = current_balance - p_ksp_amount,
        total_spent = COALESCE(total_spent, 0) + p_ksp_amount,
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING current_balance INTO v_new_reward_ksp;

    -- 8. Credit Wallet USD
    UPDATE public.wallets
    SET available_balance = available_balance + v_usd_credit,
        updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING available_balance INTO v_new_wallet_usd;

    -- 9. Record Completed Transaction
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
        p_idempotency_key,
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

    -- 10. Record User Notification
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

    -- 11. Calculate Unified Balances
    v_new_wallet_ksp := FLOOR(COALESCE(v_new_wallet_usd, 0) * 1000);
    v_new_effective_ksp := COALESCE(v_new_reward_ksp, 0) + v_new_wallet_ksp;

    -- 12. Return Response matching KspBalanceService
    RETURN jsonb_build_object(
        'success', true,
        'redeemed_ksp', p_ksp_amount,
        'usd_credited', v_usd_credit,
        'reward_ksp', v_new_reward_ksp,
        'wallet_usd', v_new_wallet_usd,
        'wallet_ksp', v_new_wallet_ksp,
        'effective_ksp', v_new_effective_ksp
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.fn_redeem_ksp_to_wallet(INT, TEXT) TO authenticated, service_role;
