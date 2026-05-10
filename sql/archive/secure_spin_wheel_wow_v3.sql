-- ============================================================
-- 🔐 SECURE SPIN WHEEL SYSTEM V3 (WOW UX & SEVEN BUNDLE)
-- ============================================================

BEGIN;

-- 1. Create buy_spins_bundle RPC function (Updated for 1, 3, 7 bundles)
CREATE OR REPLACE FUNCTION public.buy_spins_bundle(
    p_bundle_type TEXT -- 'single' (100), 'triple' (300), 'septuple' (500)
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_points_cost INTEGER;
    v_spins_to_add INTEGER;
    v_user_balance INTEGER;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- [1] Define costs and counts
    IF p_bundle_type = 'single' THEN
        v_points_cost := 100;
        v_spins_to_add := 1;
    ELSIF p_bundle_type = 'triple' THEN
        v_points_cost := 300;
        v_spins_to_add := 3;
    ELSIF p_bundle_type = 'septuple' THEN
        v_points_cost := 500;
        v_spins_to_add := 7; -- WOW Value: 7 spins for 500!
    ELSE
        RETURN json_build_object('success', false, 'error', 'Invalid bundle type');
    END IF;

    -- [2] Lock and check balance
    SELECT current_balance INTO v_user_balance FROM public.user_points WHERE user_id = v_user_id FOR UPDATE;
    
    IF v_user_balance IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'User points account not found');
    END IF;

    IF v_user_balance < v_points_cost THEN
        RETURN json_build_object('success', false, 'error', 'Insufficient points');
    END IF;

    -- [3] Deduct points
    UPDATE public.user_points
    SET current_balance = current_balance - v_points_cost,
        total_spent = total_spent + v_points_cost,
        updated_at = NOW()
    WHERE user_id = v_user_id;

    -- [4] Add stored spins
    UPDATE public.profiles
    SET stored_spins = COALESCE(stored_spins, 0) + v_spins_to_add,
        updated_at = NOW()
    WHERE id = v_user_id;

    -- [6] Return result with final states
    DECLARE
        v_final_spins INTEGER;
    BEGIN
        SELECT stored_spins INTO v_final_spins FROM public.profiles WHERE id = v_user_id;

        RETURN json_build_object(
            'success', true,
            'message', 'Bundle purchased successfully',
            'added_spins', v_spins_to_add,
            'stored_spins', v_final_spins,
            'new_balance', (v_user_balance - v_points_cost)
        );
    END;
END;
$$;

-- 2. Create core spin_wheel RPC function (Updated to block direct paid spins)
CREATE OR REPLACE FUNCTION public.spin_wheel()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
    v_selected_reward RECORD;
    v_spin_type TEXT;
    v_total_weight INTEGER;
    v_random_num INTEGER;
    v_cumulative_weight INTEGER := 0;
BEGIN
    -- [1] Authentication Check
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    -- [2] Lock user profile
    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'User account not found');
    END IF;

    -- [3] Priority Logic: Free -> Stored (ONLY)
    -- Direct paid spins are now blocked to ensure user buys bundles first for better UX
    
    -- Check for Free Spin (24h)
    IF v_profile.last_free_spin_at IS NULL OR v_profile.last_free_spin_at < NOW() - INTERVAL '24 hours' THEN
        v_spin_type := 'free';
        -- Update cooldown
        UPDATE public.profiles SET last_free_spin_at = NOW() WHERE id = v_user_id;
        
    -- Check for Stored Spins
    ELSIF COALESCE(v_profile.stored_spins, 0) > 0 THEN
        v_spin_type := 'stored';
        -- Consume one stored spin
        UPDATE public.profiles SET stored_spins = stored_spins - 1 WHERE id = v_user_id;
        
    -- Block if none available
    ELSE
        RETURN json_build_object('success', false, 'error', 'no_spins_available');
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

    -- [5] Update User Balance with Reward
    IF v_selected_reward.points > 0 THEN
        UPDATE public.user_points
        SET current_balance = current_balance + v_selected_reward.points,
            total_earned = total_earned + v_selected_reward.points,
            updated_at = NOW()
        WHERE user_id = v_user_id;

        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (v_user_id, v_selected_reward.points, 'earn', 'Spin Wheel Reward: ' || v_selected_reward.label);
    END IF;

    -- [6] Log Spin History
    INSERT INTO public.spin_history (user_id, reward_id, reward_json, spin_type, points_cost)
    VALUES (
        v_user_id, 
        v_selected_reward.id, 
        row_to_json(v_selected_reward)::jsonb, 
        v_spin_type, 
        0 -- Costs are handled during bundle purchase now
    );

    -- [7] Return result
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
