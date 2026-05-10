-- ============================================================
-- 💰 DELAYED EARNINGS (PENDING REWARDS) SYSTEM
-- ============================================================

BEGIN;

-- 1. Create reward type enum
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'reward_type') THEN
        CREATE TYPE reward_type AS ENUM ('investment', 'spin', 'bonus', 'referral');
    END IF;
END $$;

-- 2. Create pending_rewards table
CREATE TABLE IF NOT EXISTS public.pending_rewards (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount      NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    type        reward_type NOT NULL,
    status      TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'released')),
    release_at  TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.pending_rewards ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view their own pending rewards" ON public.pending_rewards;
CREATE POLICY "Users can view their own pending rewards" ON public.pending_rewards
FOR SELECT USING (auth.uid() = user_id);

-- Create Index for performance
CREATE INDEX IF NOT EXISTS idx_pending_rewards_user_status_release ON public.pending_rewards(user_id, status, release_at);

-- 3. Create claim_rewards RPC function
-- This function moves all released rewards to user's wallet/points
CREATE OR REPLACE FUNCTION public.claim_rewards()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_released_rows RECORD;
    v_total_points INTEGER := 0;
    v_total_funds NUMERIC(18, 4) := 0;
    v_summary JSONB := '[]'::jsonb;
    v_row_count INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- [1] Lock relevant tables
    -- Note: We use FOR UPDATE to prevent race conditions during point/wallet updates
    PERFORM 1 FROM public.user_points WHERE user_id = v_user_id FOR UPDATE;
    PERFORM 1 FROM public.wallets WHERE user_id = v_user_id AND currency = 'USD' FOR UPDATE;

    -- [2] Process each ready reward
    FOR v_released_rows IN 
        SELECT * FROM public.pending_rewards 
        WHERE user_id = v_user_id 
        AND status = 'pending' 
        AND release_at <= NOW()
        FOR UPDATE
    LOOP
        v_row_count := v_row_count + 1;
        
        -- Categorize by type (Spins/Bonuses usually go to points, Investments to USD wallet)
        IF v_released_rows.type IN ('spin', 'bonus') THEN
            v_total_points := v_total_points + v_released_rows.amount::INTEGER;
        ELSE
            v_total_funds := v_total_funds + v_released_rows.amount;
        END IF;

        -- Add to summary for frontend notifications
        v_summary := v_summary || jsonb_build_object(
            'type', v_released_rows.type,
            'amount', v_released_rows.amount,
            'id', v_released_rows.id
        );

        -- Mark as released
        UPDATE public.pending_rewards SET status = 'released' WHERE id = v_released_rows.id;
    END LOOP;

    -- [3] If no rewards found
    IF v_row_count = 0 THEN
        RETURN json_build_object('success', false, 'error', 'No rewards ready for claim');
    END IF;

    -- [4] Apply updates
    
    -- Update Points
    IF v_total_points > 0 THEN
        UPDATE public.user_points
        SET current_balance = current_balance + v_total_points,
            total_earned = total_earned + v_total_points,
            updated_at = NOW()
        WHERE user_id = v_user_id;

        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (v_user_id, v_total_points, 'earn', 'Claimed released rewards');
    END IF;

    -- Update Wallet Funds
    IF v_total_funds > 0 THEN
        UPDATE public.wallets
        SET available_balance = available_balance + v_total_funds,
            updated_at = NOW()
        WHERE user_id = v_user_id AND currency = 'USD';

        INSERT INTO public.transactions (
            user_id, type, amount, status, description
        ) VALUES (
            v_user_id, 'profit', v_total_funds, 'completed', 'Claimed released earnings'
        );
    END IF;

    -- [5] Return success with summary
    RETURN json_build_object(
        'success', true,
        'message', 'Rewards claimed successfully',
        'total_points', v_total_points,
        'total_funds', v_total_funds,
        'claimed_count', v_row_count,
        'rewards', v_summary
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMIT;
