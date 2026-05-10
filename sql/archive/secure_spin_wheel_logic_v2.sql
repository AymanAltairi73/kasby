-- ============================================================
-- 🔐 SECURE SPIN WHEEL SYSTEM V2 (BUNDLES & STORED SPINS)
-- ============================================================

BEGIN;

-- 1. Ensure columns exist in profiles
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'last_free_spin_at') THEN
        ALTER TABLE public.profiles ADD COLUMN last_free_spin_at TIMESTAMPTZ;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'stored_spins') THEN
        ALTER TABLE public.profiles ADD COLUMN stored_spins INTEGER DEFAULT 0;
    END IF;
END $$;

-- 2. Ensure spin_history table exists
CREATE TABLE IF NOT EXISTS public.spin_history (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reward_id   UUID REFERENCES public.spin_wheel_rewards(id),
    reward_json JSONB NOT NULL,
    spin_type   TEXT NOT NULL, -- 'free', 'stored', 'paid'
    points_cost INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.spin_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view their own spin history" ON public.spin_history;
CREATE POLICY "Users can view their own spin history" ON public.spin_history
FOR SELECT USING (auth.uid() = user_id);

-- 3. Create buy_spins_bundle RPC function
CREATE OR REPLACE FUNCTION public.buy_spins_bundle(
    p_bundle_type TEXT -- 'single' (100), 'triple' (300), 'quintuple' (500)
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_points_cost INTEGER;
    v_spins_to_add INTEGER;
    v_user_points RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- Define costs and counts
    IF p_bundle_type = 'single' THEN
        v_points_cost := 100;
        v_spins_to_add := 1;
    ELSIF p_bundle_type = 'triple' THEN
        v_points_cost := 300;
        v_spins_to_add := 3;
    ELSIF p_bundle_type = 'quintuple' THEN
        v_points_cost := 500;
        v_spins_to_add := 5;
    ELSE
        RETURN json_build_object('success', false, 'error', 'Invalid bundle type');
    END IF;

    -- Lock and check balance
    SELECT * INTO v_user_points FROM public.user_points WHERE user_id = v_user_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'User points account not found');
    END IF;

    IF v_user_points.current_balance < v_points_cost THEN
        RETURN json_build_object('success', false, 'error', 'Insufficient points');
    END IF;

    -- Deduct points
    UPDATE public.user_points
    SET current_balance = current_balance - v_points_cost,
        total_spent = total_spent + v_points_cost,
        updated_at = NOW()
    WHERE user_id = v_user_id;

    -- Add stored spins
    UPDATE public.profiles
    SET stored_spins = COALESCE(stored_spins, 0) + v_spins_to_add,
        updated_at = NOW()
    WHERE id = v_user_id;

    -- Log transaction
    INSERT INTO public.point_history (user_id, points, type, description)
    VALUES (v_user_id, -v_points_cost, 'spend', 'Buy Spins Bundle: ' || p_bundle_type);

    RETURN json_build_object(
        'success', true,
        'message', 'Bundle purchased successfully',
        'added_spins', v_spins_to_add,
        'new_balance', (v_user_points.current_balance - v_points_cost)
    );
END;
$$;

-- 4. Create core spin_wheel RPC function (Updated with priority logic)
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
    v_points_cost INTEGER := 100;
    v_spin_type TEXT := 'paid'; -- Default
    v_total_weight INTEGER;
    v_random_num INTEGER;
    v_cumulative_weight INTEGER := 0;
BEGIN
    -- [1] Authentication Check
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- [2] Lock user resources
    SELECT * INTO v_user_points FROM public.user_points WHERE user_id = v_user_id FOR UPDATE;
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'User account not found');
    END IF;

    -- [3] Priority Logic: Free -> Stored -> Paid
    
    -- Check for Free Spin (24h)
    IF v_profile.last_free_spin_at IS NULL OR v_profile.last_free_spin_at < NOW() - INTERVAL '24 hours' THEN
        v_spin_type := 'free';
        v_points_cost := 0;
        
        -- Update cooldown
        UPDATE public.profiles SET last_free_spin_at = NOW() WHERE id = v_user_id;
        
    -- Check for Stored Spins
    ELSIF COALESCE(v_profile.stored_spins, 0) > 0 THEN
        v_spin_type := 'stored';
        v_points_cost := 0;
        
        -- Consume one stored spin
        UPDATE public.profiles SET stored_spins = stored_spins - 1 WHERE id = v_user_id;
        
    -- Check for Points (Paid)
    ELSE
        IF v_user_points.current_balance < v_points_cost THEN
            RETURN json_build_object('success', false, 'error', 'Insufficient points or spins');
        END IF;
        
        v_spin_type := 'paid';
        
        -- Deduct points
        UPDATE public.user_points
        SET current_balance = current_balance - v_points_cost,
            total_spent = total_spent + v_points_cost,
            updated_at = NOW()
        WHERE user_id = v_user_id;

        -- Record point deduction
        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (v_user_id, -v_points_cost, 'spend', 'Spin Wheel - Paid Spin');
    END IF;

    -- [4] Random Reward Selection (Weighted)
    SELECT SUM(weight) INTO v_total_weight FROM public.spin_wheel_rewards WHERE is_active = TRUE;
    v_random_num := floor(random() * v_total_weight) + 1;

    FOR v_selected_reward IN 
        SELECT * FROM public.spin_wheel_rewards WHERE is_active = TRUE ORDER BY id
    LOOP
        v_cumulative_weight := v_cumulative_weight + v_selected_reward.weight;
        IF v_random_num <= v_cumulative_weight THEN
            EXIT;
        END IF;
    END LOOP;

    -- [5] Update User Balance with Reward (NOW DELAYED)
    IF v_selected_reward.points > 0 THEN
        -- Insert into pending_rewards instead of direct balance update
        INSERT INTO public.pending_rewards (
            user_id, 
            amount, 
            type, 
            status, 
            release_at
        ) VALUES (
            v_user_id, 
            v_selected_reward.points, 
            'spin', 
            'pending', 
            NOW() + INTERVAL '24 hours'
        );

        -- Optional: Log that it is pending in history
        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (v_user_id, v_selected_reward.points, 'earn', 'Spin Wheel Pending: ' || v_selected_reward.label);
    END IF;

    -- [6] Log Spin History
    INSERT INTO public.spin_history (user_id, reward_id, reward_json, spin_type, points_cost)
    VALUES (
        v_user_id, 
        v_selected_reward.id, 
        row_to_json(v_selected_reward)::jsonb, 
        v_spin_type, 
        v_points_cost
    );

    -- [7] Return result
    -- Fetch final state for consistency
    DECLARE
        v_final_points INTEGER;
        v_final_spins INTEGER;
    BEGIN
        SELECT current_balance INTO v_final_points FROM public.user_points WHERE user_id = v_user_id;
        SELECT stored_spins INTO v_final_spins FROM public.profiles WHERE id = v_user_id;

        RETURN json_build_object(
            'success', true,
            'reward', json_build_object(
                'id', v_selected_reward.id,
                'label', v_selected_reward.label,
                'points', v_selected_reward.points,
                'icon', v_selected_reward.icon,
                'color', v_selected_reward.color
            ),
            'spin_type', v_spin_type,
            'new_balance', v_final_points,
            'stored_spins', v_final_spins
        );
    END;
END;
$$;

COMMIT;
