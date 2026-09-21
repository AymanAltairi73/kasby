-- spin_wheel credits reward KSP via unified helper and returns effective balance.

CREATE OR REPLACE FUNCTION public.spin_wheel()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_user_profile RECORD;
    v_reward_profile RECORD;
    v_selected RECORD;
    v_spin_type text;
    v_total_weight integer;
    v_random_num integer;
    v_cumulative_weight integer := 0;
    v_last_spin_at timestamptz;
    v_reward_json jsonb;
    v_balance jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT * INTO v_user_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'profile_not_found');
    END IF;

    IF v_user_profile.status IN ('blocked', 'suspended') THEN
        RETURN json_build_object('success', false, 'error', 'account_restricted');
    END IF;

    SELECT * INTO v_reward_profile FROM public.get_active_spin_wheel_profile();
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'no_active_reward_profile');
    END IF;

    SELECT created_at INTO v_last_spin_at
    FROM public.spin_history
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_spin_at IS NOT NULL AND v_last_spin_at > NOW() - INTERVAL '3 seconds' THEN
        RETURN json_build_object('success', false, 'error', 'spin_too_fast');
    END IF;

    IF v_user_profile.last_free_spin_at IS NULL
       OR v_user_profile.last_free_spin_at < NOW() - INTERVAL '24 hours' THEN
        v_spin_type := 'free';
        UPDATE public.profiles
        SET last_free_spin_at = NOW(), updated_at = NOW()
        WHERE id = v_user_id;
    ELSIF COALESCE(v_user_profile.stored_spins, 0) > 0 THEN
        v_spin_type := 'stored';
        UPDATE public.profiles
        SET stored_spins = stored_spins - 1, updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        RETURN json_build_object('success', false, 'error', 'no_spins_available');
    END IF;

    SELECT COALESCE(SUM(pw.weight), 0) INTO v_total_weight
    FROM public.spin_wheel_profile_weights pw
    JOIN public.spin_wheel_rewards r ON r.id = pw.reward_id
    WHERE pw.profile_id = v_reward_profile.id
      AND r.is_active = true;

    IF v_total_weight <= 0 THEN
        RETURN json_build_object('success', false, 'error', 'no_active_rewards');
    END IF;

    v_random_num := floor(random() * v_total_weight)::integer + 1;

    FOR v_selected IN
        SELECT r.*, pw.weight AS profile_weight
        FROM public.spin_wheel_rewards r
        JOIN public.spin_wheel_profile_weights pw ON pw.reward_id = r.id
        WHERE pw.profile_id = v_reward_profile.id
          AND r.is_active = true
        ORDER BY r.display_order, r.id
    LOOP
        v_cumulative_weight := v_cumulative_weight + v_selected.profile_weight;
        IF v_random_num <= v_cumulative_weight THEN
            EXIT;
        END IF;
    END LOOP;

    IF v_selected.id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'reward_selection_failed');
    END IF;

    IF v_selected.points > 0 THEN
        PERFORM public.fn_credit_reward_ksp(
            v_user_id,
            v_selected.points,
            'Spin Wheel Reward: ' || v_selected.label,
            v_selected.id::text
        );
    END IF;

    v_reward_json := row_to_json(v_selected)::jsonb
        || jsonb_build_object(
            'profile_id', v_reward_profile.id,
            'profile_slug', v_reward_profile.slug,
            'profile_name', v_reward_profile.name,
            'profile_weight', v_selected.profile_weight
        );

    INSERT INTO public.spin_history (
        user_id, reward_id, reward_json, spin_type,
        profile_id, profile_slug, profile_name, profile_weight
    ) VALUES (
        v_user_id,
        v_selected.id,
        v_reward_json,
        v_spin_type,
        v_reward_profile.id,
        v_reward_profile.slug,
        v_reward_profile.name,
        v_selected.profile_weight
    );

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        v_user_id,
        'user',
        'spin_reward_granted',
        'spin_wheel_reward',
        v_selected.id::text,
        jsonb_build_object(
            'label', v_selected.label,
            'points', v_selected.points,
            'spin_type', v_spin_type,
            'profile_slug', v_reward_profile.slug,
            'profile_name', v_reward_profile.name,
            'profile_weight', v_selected.profile_weight
        ),
        CASE WHEN v_selected.points >= 200 THEN 'warning' ELSE 'info' END
    );

    v_balance := public.fn_get_effective_ksp(v_user_id);

    RETURN json_build_object(
        'success', true,
        'reward', json_build_object(
            'id', v_selected.id,
            'label', v_selected.label,
            'points', v_selected.points,
            'icon', v_selected.icon,
            'color', v_selected.color
        ),
        'profile', json_build_object(
            'id', v_reward_profile.id,
            'slug', v_reward_profile.slug,
            'name', v_reward_profile.name
        ),
        'spin_type', v_spin_type,
        'new_balance', (v_balance->>'effective_ksp')::integer,
        'effective_ksp', (v_balance->>'effective_ksp')::integer,
        'reward_ksp', (v_balance->>'reward_ksp')::integer,
        'wallet_ksp', (v_balance->>'wallet_ksp')::integer,
        'stored_spins', (SELECT stored_spins FROM public.profiles WHERE id = v_user_id)
    );
END;
$$;
