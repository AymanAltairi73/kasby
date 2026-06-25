-- Lucky Wheel production hardening: normalize rewards, constraints, audit logs,
-- hardened spin_wheel RPC, admin management RPCs, and analytics support.

-- ─── 1. Normalize legacy reward rows ───────────────────────────────────────
UPDATE public.spin_wheel_rewards
SET label = 'gift',
    points = 500,
    icon = 'card_giftcard_rounded',
    color = '#0D0D0D',
    updated_at = NOW()
WHERE lower(trim(label)) IN ('bonus', 'gift')
  AND points = 0;

UPDATE public.spin_wheel_rewards
SET icon = 'monetization_on_rounded',
    updated_at = NOW()
WHERE label = '200'
  AND icon = 'card_giftcard_rounded';

-- ─── 2. Display order for consistent wheel layout ────────────────────────────
ALTER TABLE public.spin_wheel_rewards
    ADD COLUMN IF NOT EXISTS display_order integer DEFAULT 0;

UPDATE public.spin_wheel_rewards SET display_order = CASE lower(trim(label))
    WHEN '10' THEN 0
    WHEN '25' THEN 1
    WHEN '50' THEN 2
    WHEN '100' THEN 3
    WHEN '0' THEN 4
    WHEN '5' THEN 5
    WHEN '200' THEN 6
    WHEN 'gift' THEN 7
    ELSE 99
END;

-- ─── 3. Integrity constraints ────────────────────────────────────────────────
ALTER TABLE public.spin_wheel_rewards
    DROP CONSTRAINT IF EXISTS spin_wheel_rewards_weight_positive;

ALTER TABLE public.spin_wheel_rewards
    ADD CONSTRAINT spin_wheel_rewards_weight_positive CHECK (weight > 0);

ALTER TABLE public.spin_wheel_rewards
    DROP CONSTRAINT IF EXISTS spin_wheel_rewards_points_non_negative;

ALTER TABLE public.spin_wheel_rewards
    ADD CONSTRAINT spin_wheel_rewards_points_non_negative CHECK (points >= 0);

CREATE OR REPLACE FUNCTION public.spin_wheel_reward_label_valid(
    p_label text,
    p_points integer
) RETURNS boolean
    LANGUAGE sql
    IMMUTABLE
AS $$
    SELECT
        lower(trim(p_label)) IN ('gift', 'bonus')
        OR lower(trim(p_label)) = '0'
        OR (
            p_label ~ '^[0-9]+$'
            AND p_label::integer = p_points
        );
$$;

ALTER TABLE public.spin_wheel_rewards
    DROP CONSTRAINT IF EXISTS spin_wheel_rewards_label_points_match;

ALTER TABLE public.spin_wheel_rewards
    ADD CONSTRAINT spin_wheel_rewards_label_points_match
    CHECK (public.spin_wheel_reward_label_valid(label, points));

-- ─── 4. RLS: admin full access + analytics read on spin_history ──────────────
DROP POLICY IF EXISTS "Admins manage spin_wheel_rewards" ON public.spin_wheel_rewards;
CREATE POLICY "Admins manage spin_wheel_rewards"
    ON public.spin_wheel_rewards
    FOR ALL
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins view all spin history" ON public.spin_history;
CREATE POLICY "Admins view all spin history"
    ON public.spin_history
    FOR SELECT
    USING (public.is_admin());

-- ─── 5. Hardened spin_wheel() with rate limit + audit logging ────────────────
CREATE OR REPLACE FUNCTION public.spin_wheel() RETURNS json
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_profile RECORD;
    v_selected_reward RECORD;
    v_spin_type TEXT;
    v_total_weight INTEGER;
    v_random_num INTEGER;
    v_cumulative_weight INTEGER := 0;
    v_last_spin_at TIMESTAMPTZ;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'profile_not_found');
    END IF;

    IF v_profile.status IN ('blocked', 'suspended') THEN
        RETURN json_build_object('success', false, 'error', 'account_restricted');
    END IF;

    -- Anti-race: minimum 3 seconds between spins per user
    SELECT created_at INTO v_last_spin_at
    FROM public.spin_history
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_spin_at IS NOT NULL AND v_last_spin_at > NOW() - INTERVAL '3 seconds' THEN
        RETURN json_build_object('success', false, 'error', 'spin_too_fast');
    END IF;

    -- Free spin every 24h, then stored spins
    IF v_profile.last_free_spin_at IS NULL
       OR v_profile.last_free_spin_at < NOW() - INTERVAL '24 hours' THEN
        v_spin_type := 'free';
        UPDATE public.profiles
        SET last_free_spin_at = NOW(), updated_at = NOW()
        WHERE id = v_user_id;
    ELSIF COALESCE(v_profile.stored_spins, 0) > 0 THEN
        v_spin_type := 'stored';
        UPDATE public.profiles
        SET stored_spins = stored_spins - 1, updated_at = NOW()
        WHERE id = v_user_id;
    ELSE
        RETURN json_build_object('success', false, 'error', 'no_spins_available');
    END IF;

    SELECT COALESCE(SUM(weight), 0) INTO v_total_weight
    FROM public.spin_wheel_rewards
    WHERE is_active = TRUE;

    IF v_total_weight <= 0 THEN
        RETURN json_build_object('success', false, 'error', 'no_active_rewards');
    END IF;

    v_random_num := floor(random() * v_total_weight)::integer + 1;

    FOR v_selected_reward IN
        SELECT * FROM public.spin_wheel_rewards
        WHERE is_active = TRUE
        ORDER BY display_order, id
    LOOP
        v_cumulative_weight := v_cumulative_weight + v_selected_reward.weight;
        IF v_random_num <= v_cumulative_weight THEN
            EXIT;
        END IF;
    END LOOP;

    IF v_selected_reward.id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'reward_selection_failed');
    END IF;

    IF v_selected_reward.points > 0 THEN
        PERFORM public.ensure_user_points(v_user_id);

        UPDATE public.user_points
        SET current_balance = current_balance + v_selected_reward.points,
            total_earned = total_earned + v_selected_reward.points,
            updated_at = NOW()
        WHERE user_id = v_user_id;

        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (
            v_user_id,
            v_selected_reward.points,
            'earn',
            'Spin Wheel Reward: ' || v_selected_reward.label
        );
    END IF;

    INSERT INTO public.spin_history (user_id, reward_id, reward_json, spin_type)
    VALUES (
        v_user_id,
        v_selected_reward.id,
        row_to_json(v_selected_reward)::jsonb,
        v_spin_type
    );

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        v_user_id,
        'user',
        'spin_reward_granted',
        'spin_wheel_reward',
        v_selected_reward.id::text,
        jsonb_build_object(
            'label', v_selected_reward.label,
            'points', v_selected_reward.points,
            'spin_type', v_spin_type,
            'weight', v_selected_reward.weight
        ),
        CASE WHEN v_selected_reward.points >= 200 THEN 'warning' ELSE 'info' END
    );

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
        'new_balance', COALESCE(
            (SELECT current_balance FROM public.user_points WHERE user_id = v_user_id),
            0
        ),
        'stored_spins', (SELECT stored_spins FROM public.profiles WHERE id = v_user_id)
    );
END;
$$;

-- ─── 6. Admin CRUD RPCs ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_upsert_spin_reward(p_payload jsonb)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_id UUID;
    v_label TEXT;
    v_points INTEGER;
    v_icon TEXT;
    v_color TEXT;
    v_weight INTEGER;
    v_is_active BOOLEAN;
    v_display_order INTEGER;
    v_action TEXT;
    v_old RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    v_id := NULLIF(p_payload->>'id', '')::uuid;
    v_label := trim(p_payload->>'label');
    v_points := COALESCE((p_payload->>'points')::integer, 0);
    v_icon := COALESCE(NULLIF(trim(p_payload->>'icon'), ''), 'stars_rounded');
    v_color := COALESCE(NULLIF(trim(p_payload->>'color'), ''), '#C9A24D');
    v_weight := COALESCE((p_payload->>'weight')::integer, 1);
    v_is_active := COALESCE((p_payload->>'is_active')::boolean, true);
    v_display_order := COALESCE((p_payload->>'display_order')::integer, 0);

    IF v_label IS NULL OR v_label = '' THEN
        RAISE EXCEPTION 'Label is required';
    END IF;
    IF v_weight <= 0 THEN
        RAISE EXCEPTION 'Weight must be greater than zero';
    END IF;
    IF NOT public.spin_wheel_reward_label_valid(v_label, v_points) THEN
        RAISE EXCEPTION 'Label must match points (numeric labels) or be gift/0';
    END IF;

    IF v_id IS NOT NULL THEN
        SELECT * INTO v_old FROM public.spin_wheel_rewards WHERE id = v_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Reward not found';
        END IF;

        UPDATE public.spin_wheel_rewards
        SET label = v_label,
            points = v_points,
            icon = v_icon,
            color = v_color,
            weight = v_weight,
            is_active = v_is_active,
            display_order = v_display_order,
            updated_at = NOW()
        WHERE id = v_id;

        v_action := 'reward_updated';
    ELSE
        INSERT INTO public.spin_wheel_rewards (
            label, points, icon, color, weight, is_active, display_order
        ) VALUES (
            v_label, v_points, v_icon, v_color, v_weight, v_is_active, v_display_order
        )
        RETURNING id INTO v_id;

        v_action := 'reward_created';
    END IF;

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(),
        'admin',
        v_action,
        'spin_wheel_reward',
        v_id::text,
        jsonb_build_object(
            'label', v_label,
            'points', v_points,
            'weight', v_weight,
            'is_active', v_is_active,
            'previous', CASE WHEN v_old.id IS NOT NULL THEN row_to_json(v_old)::jsonb ELSE NULL END
        ),
        'info'
    );

    IF v_old.id IS NOT NULL AND v_old.weight IS DISTINCT FROM v_weight THEN
        INSERT INTO public.system_logs (
            actor_id, actor_role, action, entity_type, entity_id, details, severity
        ) VALUES (
            auth.uid(),
            'admin',
            'weight_changed',
            'spin_wheel_reward',
            v_id::text,
            jsonb_build_object('old_weight', v_old.weight, 'new_weight', v_weight),
            'warning'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_id,
        'action', v_action
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_spin_reward_status(
    p_reward_id uuid,
    p_is_active boolean
)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    UPDATE public.spin_wheel_rewards
    SET is_active = p_is_active, updated_at = NOW()
    WHERE id = p_reward_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reward not found';
    END IF;

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(),
        'admin',
        CASE WHEN p_is_active THEN 'reward_enabled' ELSE 'reward_disabled' END,
        'spin_wheel_reward',
        p_reward_id::text,
        jsonb_build_object('is_active', p_is_active),
        'info'
    );

    RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_spin_reward(p_reward_id uuid)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_history_count INTEGER;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    SELECT COUNT(*) INTO v_history_count
    FROM public.spin_history
    WHERE reward_id = p_reward_id;

    IF v_history_count > 0 THEN
        UPDATE public.spin_wheel_rewards
        SET is_active = false, updated_at = NOW()
        WHERE id = p_reward_id;

        INSERT INTO public.system_logs (
            actor_id, actor_role, action, entity_type, entity_id, details, severity
        ) VALUES (
            auth.uid(), 'admin', 'reward_disabled', 'spin_wheel_reward',
            p_reward_id::text,
            jsonb_build_object('reason', 'has_spin_history', 'history_count', v_history_count),
            'warning'
        );

        RETURN jsonb_build_object('success', true, 'soft_deleted', true);
    END IF;

    DELETE FROM public.spin_wheel_rewards WHERE id = p_reward_id;

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(), 'admin', 'reward_deleted', 'spin_wheel_reward',
        p_reward_id::text, '{}'::jsonb, 'warning'
    );

    RETURN jsonb_build_object('success', true, 'soft_deleted', false);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_get_spin_wheel_analytics()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_overview jsonb;
    v_reward_stats jsonb;
    v_top_winners jsonb;
    v_active_users jsonb;
    v_suspicious jsonb;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    SELECT jsonb_build_object(
        'total_spins', COUNT(*),
        'spins_today', COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE),
        'spins_this_month', COUNT(*) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)),
        'active_users', COUNT(DISTINCT user_id),
        'total_ksp_distributed', COALESCE(SUM((reward_json->>'points')::integer), 0),
        'daily_ksp', COALESCE(
            SUM((reward_json->>'points')::integer)
                FILTER (WHERE created_at >= CURRENT_DATE),
            0
        ),
        'monthly_ksp', COALESCE(
            SUM((reward_json->>'points')::integer)
                FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)),
            0
        )
    ) INTO v_overview
    FROM public.spin_history;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.win_count DESC), '[]'::jsonb)
    INTO v_reward_stats
    FROM (
        SELECT
            r.label,
            r.points,
            r.weight,
            COUNT(sh.id) AS win_count,
            COALESCE(SUM((sh.reward_json->>'points')::integer), 0) AS total_ksp,
            ROUND(
                COUNT(sh.id)::numeric / NULLIF((SELECT COUNT(*) FROM public.spin_history), 0) * 100,
                2
            ) AS actual_win_pct,
            ROUND(
                r.weight::numeric / NULLIF(
                    (SELECT SUM(weight) FROM public.spin_wheel_rewards WHERE is_active),
                    0
                ) * 100,
                2
            ) AS expected_win_pct
        FROM public.spin_wheel_rewards r
        LEFT JOIN public.spin_history sh ON sh.reward_id = r.id
        GROUP BY r.id, r.label, r.points, r.weight
    ) t;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.total_won DESC), '[]'::jsonb)
    INTO v_top_winners
    FROM (
        SELECT
            sh.user_id,
            p.full_name,
            COUNT(*) AS spin_count,
            COALESCE(SUM((sh.reward_json->>'points')::integer), 0) AS total_won
        FROM public.spin_history sh
        LEFT JOIN public.profiles p ON p.id = sh.user_id
        GROUP BY sh.user_id, p.full_name
        ORDER BY total_won DESC
        LIMIT 10
    ) t;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.spin_count DESC), '[]'::jsonb)
    INTO v_active_users
    FROM (
        SELECT
            sh.user_id,
            p.full_name,
            COUNT(*) AS spin_count
        FROM public.spin_history sh
        LEFT JOIN public.profiles p ON p.id = sh.user_id
        GROUP BY sh.user_id, p.full_name
        ORDER BY spin_count DESC
        LIMIT 10
    ) t;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_suspicious
    FROM (
        SELECT
            sh.user_id,
            p.full_name,
            COUNT(*) AS spins_last_hour,
            COALESCE(SUM((sh.reward_json->>'points')::integer), 0) AS ksp_last_hour
        FROM public.spin_history sh
        LEFT JOIN public.profiles p ON p.id = sh.user_id
        WHERE sh.created_at >= NOW() - INTERVAL '1 hour'
        GROUP BY sh.user_id, p.full_name
        HAVING COUNT(*) >= 10
    ) t;

    RETURN jsonb_build_object(
        'overview', v_overview,
        'reward_stats', v_reward_stats,
        'top_winners', v_top_winners,
        'most_active', v_active_users,
        'suspicious', v_suspicious
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_upsert_spin_reward(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_set_spin_reward_status(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_delete_spin_reward(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_get_spin_wheel_analytics() TO authenticated;
