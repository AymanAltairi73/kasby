-- ============================================================
-- 🔐 SECURE SPIN WHEEL SYSTEM (BACKEND LOGIC)
-- ============================================================

BEGIN;

-- 1. Ensure last_free_spin_at exists in profiles
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'last_free_spin_at') THEN
        ALTER TABLE public.profiles ADD COLUMN last_free_spin_at TIMESTAMPTZ;
    END IF;
END $$;

-- 2. Create spin_history table
CREATE TABLE IF NOT EXISTS public.spin_history (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reward_id   UUID REFERENCES public.spin_wheel_rewards(id),
    reward_json JSONB NOT NULL,
    is_free     BOOLEAN DEFAULT FALSE,
    points_cost INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.spin_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view their own spin history" ON public.spin_history;
CREATE POLICY "Users can view their own spin history" ON public.spin_history
FOR SELECT USING (auth.uid() = user_id);

-- 3. Create core spin_wheel RPC function
CREATE OR REPLACE FUNCTION public.spin_wheel()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_points RECORD;
    v_profile RECORD;
    v_selected_reward RECORD;
    v_points_cost INTEGER := 100; -- Cost per spin if not free
    v_is_free BOOLEAN := FALSE;
    v_total_weight INTEGER;
    v_random_num INTEGER;
    v_cumulative_weight INTEGER := 0;
BEGIN
    -- [1] Authentication Check
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- [2] Lock user resources to prevent race conditions
    SELECT * INTO v_user_points FROM public.user_points WHERE user_id = v_user_id FOR UPDATE;
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'User account not found');
    END IF;

    -- [3] Check Cooldown (Once Daily / 24 Hours)
    -- User specifically asked for "once daily"
    IF v_profile.last_free_spin_at IS NULL OR v_profile.last_free_spin_at < NOW() - INTERVAL '24 hours' THEN
        v_is_free := TRUE;
    END IF;

    -- [4] Handle Points Deduction if not free
    IF NOT v_is_free THEN
        IF v_user_points.current_balance < v_points_cost THEN
            RETURN json_build_object(
                'success', false, 
                'error', 'Insufficient points', 
                'needed', v_points_cost,
                'current', v_user_points.current_balance
            );
        END IF;

        -- Deduct points
        UPDATE public.user_points
        SET current_balance = current_balance - v_points_cost,
            total_spent = total_spent + v_points_cost,
            updated_at = NOW()
        WHERE user_id = v_user_id;

        -- Record point deduction in history
        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (v_user_id, -v_points_cost, 'spend', 'Spin Wheel - Paid Spin');
    END IF;

    -- [5] Random Reward Selection (Weighted)
    SELECT SUM(weight) INTO v_total_weight FROM public.spin_wheel_rewards WHERE is_active = TRUE;
    
    -- Generate random number between 1 and v_total_weight
    v_random_num := floor(random() * v_total_weight) + 1;

    FOR v_selected_reward IN 
        SELECT * FROM public.spin_wheel_rewards WHERE is_active = TRUE ORDER BY id
    LOOP
        v_cumulative_weight := v_cumulative_weight + v_selected_reward.weight;
        IF v_random_num <= v_cumulative_weight THEN
            EXIT; -- Found our reward
        END IF;
    END LOOP;

    -- [6] Update User Balance with Reward
    IF v_selected_reward.points > 0 THEN
        UPDATE public.user_points
        SET current_balance = current_balance + v_selected_reward.points,
            total_earned = total_earned + v_selected_reward.points,
            updated_at = NOW()
        WHERE user_id = v_user_id;

        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (v_user_id, v_selected_reward.points, 'earn', 'Spin Wheel Reward: ' || v_selected_reward.label);
    END IF;

    -- [7] Update Profile Cooldown if it was a free spin
    IF v_is_free THEN
        UPDATE public.profiles
        SET last_free_spin_at = NOW()
        WHERE id = v_user_id;
    END IF;

    -- [8] Log Spin History
    INSERT INTO public.spin_history (user_id, reward_id, reward_json, is_free, points_cost)
    VALUES (
        v_user_id, 
        v_selected_reward.id, 
        row_to_json(v_selected_reward)::jsonb, 
        v_is_free, 
        CASE WHEN v_is_free THEN 0 ELSE v_points_cost END
    );

    -- [9] Return Success
    RETURN json_build_object(
        'success', true,
        'reward', json_build_object(
            'id', v_selected_reward.id,
            'label', v_selected_reward.label,
            'points', v_selected_reward.points,
            'icon', v_selected_reward.icon,
            'color', v_selected_reward.color
        ),
        'is_free', v_is_free,
        'new_balance', (v_user_points.current_balance + v_selected_reward.points - (CASE WHEN v_is_free THEN 0 ELSE v_points_cost END))
    );

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

COMMIT;
