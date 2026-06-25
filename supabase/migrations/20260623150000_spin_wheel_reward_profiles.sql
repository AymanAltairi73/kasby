-- Spin Wheel Reward Profile System
-- Probabilities live in profile weights, not on spin_wheel_rewards.weight.

-- ─── 1. Profile tables ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.spin_wheel_reward_profiles (
    id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    slug text NOT NULL UNIQUE,
    name text NOT NULL,
    description text DEFAULT ''::text,
    is_active boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS spin_wheel_reward_profiles_one_active_idx
    ON public.spin_wheel_reward_profiles (is_active)
    WHERE is_active = true;

CREATE TABLE IF NOT EXISTS public.spin_wheel_profile_weights (
    id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    profile_id uuid NOT NULL REFERENCES public.spin_wheel_reward_profiles(id) ON DELETE CASCADE,
    reward_id uuid NOT NULL REFERENCES public.spin_wheel_rewards(id) ON DELETE CASCADE,
    weight integer NOT NULL CHECK (weight > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (profile_id, reward_id)
);

-- ─── 2. spin_history: preserve profile at spin time ────────────────────────
ALTER TABLE public.spin_history
    ADD COLUMN IF NOT EXISTS profile_id uuid REFERENCES public.spin_wheel_reward_profiles(id) ON DELETE SET NULL;

ALTER TABLE public.spin_history
    ADD COLUMN IF NOT EXISTS profile_slug text;

ALTER TABLE public.spin_history
    ADD COLUMN IF NOT EXISTS profile_name text;

ALTER TABLE public.spin_history
    ADD COLUMN IF NOT EXISTS profile_weight integer;

COMMENT ON COLUMN public.spin_wheel_rewards.weight IS
    'Deprecated for probability. Use spin_wheel_profile_weights on the active profile.';

-- ─── 3. RLS ────────────────────────────────────────────────────────────────
ALTER TABLE public.spin_wheel_reward_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spin_wheel_profile_weights ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage spin_wheel_reward_profiles" ON public.spin_wheel_reward_profiles;
CREATE POLICY "Admins manage spin_wheel_reward_profiles"
    ON public.spin_wheel_reward_profiles FOR ALL
    USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins manage spin_wheel_profile_weights" ON public.spin_wheel_profile_weights;
CREATE POLICY "Admins manage spin_wheel_profile_weights"
    ON public.spin_wheel_profile_weights FOR ALL
    USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ─── 4. Seed profiles (weights by reward label) ────────────────────────────
INSERT INTO public.spin_wheel_reward_profiles (slug, name, description, is_active)
VALUES
    (
        'launch_campaign',
        'Launch Campaign',
        'Generous odds for user acquisition and early engagement.',
        false
    ),
    (
        'balanced_production',
        'Balanced Production',
        'Default production profile — sustainable EV ~22 KSP/spin.',
        true
    ),
    (
        'conservative',
        'Conservative',
        'Cost-control profile for high-growth periods.',
        false
    ),
    (
        'promotional_event',
        'Promotional Event',
        'Short-term event profile with elevated jackpot visibility.',
        false
    )
ON CONFLICT (slug) DO NOTHING;

-- Helper: upsert weight by profile slug + reward label
CREATE OR REPLACE FUNCTION public._seed_spin_profile_weight(
    p_profile_slug text,
    p_reward_label text,
    p_weight integer
) RETURNS void
    LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.spin_wheel_profile_weights (profile_id, reward_id, weight)
    SELECT p.id, r.id, p_weight
    FROM public.spin_wheel_reward_profiles p
    JOIN public.spin_wheel_rewards r ON lower(trim(r.label)) = lower(trim(p_reward_label))
    WHERE p.slug = p_profile_slug
    ON CONFLICT (profile_id, reward_id)
    DO UPDATE SET weight = EXCLUDED.weight, updated_at = now();
END;
$$;

-- Launch Campaign (EV ~34 KSP)
SELECT public._seed_spin_profile_weight('launch_campaign', '0', 20);
SELECT public._seed_spin_profile_weight('launch_campaign', '5', 18);
SELECT public._seed_spin_profile_weight('launch_campaign', '10', 15);
SELECT public._seed_spin_profile_weight('launch_campaign', '25', 11);
SELECT public._seed_spin_profile_weight('launch_campaign', '50', 8);
SELECT public._seed_spin_profile_weight('launch_campaign', '100', 5);
SELECT public._seed_spin_profile_weight('launch_campaign', '200', 2);
SELECT public._seed_spin_profile_weight('launch_campaign', 'gift', 1);

-- Balanced Production (EV ~21.75 KSP)
SELECT public._seed_spin_profile_weight('balanced_production', '0', 30);
SELECT public._seed_spin_profile_weight('balanced_production', '5', 25);
SELECT public._seed_spin_profile_weight('balanced_production', '10', 20);
SELECT public._seed_spin_profile_weight('balanced_production', '25', 12);
SELECT public._seed_spin_profile_weight('balanced_production', '50', 7);
SELECT public._seed_spin_profile_weight('balanced_production', '100', 3);
SELECT public._seed_spin_profile_weight('balanced_production', '200', 2);
SELECT public._seed_spin_profile_weight('balanced_production', 'gift', 1);

-- Conservative (EV ~12.6 KSP)
SELECT public._seed_spin_profile_weight('conservative', '0', 48);
SELECT public._seed_spin_profile_weight('conservative', '5', 30);
SELECT public._seed_spin_profile_weight('conservative', '10', 14);
SELECT public._seed_spin_profile_weight('conservative', '25', 5);
SELECT public._seed_spin_profile_weight('conservative', '50', 1);
SELECT public._seed_spin_profile_weight('conservative', '100', 1);
SELECT public._seed_spin_profile_weight('conservative', '200', 1);
SELECT public._seed_spin_profile_weight('conservative', 'gift', 1);

-- Promotional Event (EV ~39 KSP, higher gift visibility)
SELECT public._seed_spin_profile_weight('promotional_event', '0', 15);
SELECT public._seed_spin_profile_weight('promotional_event', '5', 15);
SELECT public._seed_spin_profile_weight('promotional_event', '10', 12);
SELECT public._seed_spin_profile_weight('promotional_event', '25', 10);
SELECT public._seed_spin_profile_weight('promotional_event', '50', 8);
SELECT public._seed_spin_profile_weight('promotional_event', '100', 6);
SELECT public._seed_spin_profile_weight('promotional_event', '200', 3);
SELECT public._seed_spin_profile_weight('promotional_event', 'gift', 2);

DROP FUNCTION IF EXISTS public._seed_spin_profile_weight(text, text, integer);

-- Ensure exactly one active profile
UPDATE public.spin_wheel_reward_profiles SET is_active = false;
UPDATE public.spin_wheel_reward_profiles SET is_active = true WHERE slug = 'balanced_production';

-- Backfill historical spins
UPDATE public.spin_history
SET profile_slug = COALESCE(profile_slug, 'legacy_equal_weight'),
    profile_name = COALESCE(profile_name, 'Legacy Equal Weight')
WHERE profile_slug IS NULL;

-- ─── 5. Helpers ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_active_spin_wheel_profile()
    RETURNS public.spin_wheel_reward_profiles
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    SET search_path TO public
AS $$
    SELECT *
    FROM public.spin_wheel_reward_profiles
    WHERE is_active = true
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.compute_spin_profile_ev(p_profile_id uuid)
    RETURNS numeric
    LANGUAGE sql
    STABLE
AS $$
    SELECT COALESCE(
        ROUND(
            SUM(r.points * pw.weight)::numeric / NULLIF(SUM(pw.weight), 0),
            2
        ),
        0
    )
    FROM public.spin_wheel_profile_weights pw
    JOIN public.spin_wheel_rewards r ON r.id = pw.reward_id
    WHERE pw.profile_id = p_profile_id
      AND r.is_active = true;
$$;

-- ─── 6. spin_wheel() uses active profile weights ───────────────────────────
CREATE OR REPLACE FUNCTION public.spin_wheel() RETURNS json
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_profile RECORD;
    v_reward_profile RECORD;
    v_selected RECORD;
    v_spin_type TEXT;
    v_total_weight INTEGER;
    v_random_num INTEGER;
    v_cumulative_weight INTEGER := 0;
    v_last_spin_at TIMESTAMPTZ;
    v_reward_json jsonb;
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
        PERFORM public.ensure_user_points(v_user_id);

        UPDATE public.user_points
        SET current_balance = current_balance + v_selected.points,
            total_earned = total_earned + v_selected.points,
            updated_at = NOW()
        WHERE user_id = v_user_id;

        INSERT INTO public.point_history (user_id, points, type, description)
        VALUES (
            v_user_id,
            v_selected.points,
            'earn',
            'Spin Wheel Reward: ' || v_selected.label
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
        'new_balance', COALESCE(
            (SELECT current_balance FROM public.user_points WHERE user_id = v_user_id),
            0
        ),
        'stored_spins', (SELECT stored_spins FROM public.profiles WHERE id = v_user_id)
    );
END;
$$;

-- ─── 7. Admin profile RPCs ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_spin_reward_profiles()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    RETURN COALESCE(
        (
            SELECT jsonb_agg(profile_row ORDER BY profile_row->>'slug')
            FROM (
                SELECT jsonb_build_object(
                    'id', p.id,
                    'slug', p.slug,
                    'name', p.name,
                    'description', p.description,
                    'is_active', p.is_active,
                    'expected_ev_ksp', public.compute_spin_profile_ev(p.id),
                    'total_weight', (
                        SELECT COALESCE(SUM(pw.weight), 0)
                        FROM public.spin_wheel_profile_weights pw
                        JOIN public.spin_wheel_rewards r ON r.id = pw.reward_id
                        WHERE pw.profile_id = p.id AND r.is_active = true
                    ),
                    'weights', (
                        SELECT COALESCE(jsonb_agg(
                            jsonb_build_object(
                                'reward_id', r.id,
                                'label', r.label,
                                'points', r.points,
                                'weight', pw.weight,
                                'is_active', r.is_active,
                                'display_order', r.display_order
                            ) ORDER BY r.display_order
                        ), '[]'::jsonb)
                        FROM public.spin_wheel_profile_weights pw
                        JOIN public.spin_wheel_rewards r ON r.id = pw.reward_id
                        WHERE pw.profile_id = p.id
                    ),
                    'created_at', p.created_at,
                    'updated_at', p.updated_at
                ) AS profile_row
                FROM public.spin_wheel_reward_profiles p
            ) s
        ),
        '[]'::jsonb
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_activate_spin_reward_profile(p_profile_id uuid)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_new RECORD;
    v_old RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    SELECT * INTO v_new FROM public.spin_wheel_reward_profiles WHERE id = p_profile_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    SELECT * INTO v_old FROM public.spin_wheel_reward_profiles WHERE is_active = true LIMIT 1;

    UPDATE public.spin_wheel_reward_profiles SET is_active = false, updated_at = now()
    WHERE is_active = true;

    UPDATE public.spin_wheel_reward_profiles
    SET is_active = true, updated_at = now()
    WHERE id = p_profile_id;

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(),
        'admin',
        'reward_profile_activated',
        'spin_wheel_reward_profile',
        p_profile_id::text,
        jsonb_build_object(
            'new_slug', v_new.slug,
            'new_name', v_new.name,
            'new_expected_ev_ksp', public.compute_spin_profile_ev(p_profile_id),
            'previous_slug', v_old.slug,
            'previous_name', v_old.name,
            'previous_id', v_old.id
        ),
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'active_profile_id', p_profile_id,
        'slug', v_new.slug,
        'expected_ev_ksp', public.compute_spin_profile_ev(p_profile_id)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_spin_profile_weight(
    p_profile_id uuid,
    p_reward_id uuid,
    p_weight integer
)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_old_weight integer;
    v_profile RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    IF p_weight IS NULL OR p_weight <= 0 THEN
        RAISE EXCEPTION 'Weight must be greater than zero';
    END IF;

    SELECT * INTO v_profile FROM public.spin_wheel_reward_profiles WHERE id = p_profile_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Profile not found';
    END IF;

    SELECT weight INTO v_old_weight
    FROM public.spin_wheel_profile_weights
    WHERE profile_id = p_profile_id AND reward_id = p_reward_id;

    INSERT INTO public.spin_wheel_profile_weights (profile_id, reward_id, weight)
    VALUES (p_profile_id, p_reward_id, p_weight)
    ON CONFLICT (profile_id, reward_id)
    DO UPDATE SET weight = EXCLUDED.weight, updated_at = now();

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(),
        'admin',
        'profile_weight_changed',
        'spin_wheel_reward_profile',
        p_profile_id::text,
        jsonb_build_object(
            'profile_slug', v_profile.slug,
            'reward_id', p_reward_id,
            'old_weight', v_old_weight,
            'new_weight', p_weight
        ),
        'info'
    );

    RETURN jsonb_build_object(
        'success', true,
        'expected_ev_ksp', public.compute_spin_profile_ev(p_profile_id)
    );
END;
$$;

-- Stop writing probability weights on reward rows (metadata only)
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
    v_is_active := COALESCE((p_payload->>'is_active')::boolean, true);
    v_display_order := COALESCE((p_payload->>'display_order')::integer, 0);

    IF v_label IS NULL OR v_label = '' THEN
        RAISE EXCEPTION 'Label is required';
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
            is_active = v_is_active,
            display_order = v_display_order,
            updated_at = NOW()
        WHERE id = v_id;

        v_action := 'reward_updated';
    ELSE
        INSERT INTO public.spin_wheel_rewards (
            label, points, icon, color, weight, is_active, display_order
        ) VALUES (
            v_label, v_points, v_icon, v_color, 1, v_is_active, v_display_order
        )
        RETURNING id INTO v_id;

        INSERT INTO public.spin_wheel_profile_weights (profile_id, reward_id, weight)
        SELECT p.id, v_id, 1
        FROM public.spin_wheel_reward_profiles p
        ON CONFLICT (profile_id, reward_id) DO NOTHING;

        v_action := 'reward_created';
    END IF;

    INSERT INTO public.system_logs (
        actor_id, actor_role, action, entity_type, entity_id, details, severity
    ) VALUES (
        auth.uid(), 'admin', v_action, 'spin_wheel_reward', v_id::text,
        jsonb_build_object(
            'label', v_label, 'points', v_points, 'is_active', v_is_active,
            'previous', CASE WHEN v_old.id IS NOT NULL THEN row_to_json(v_old)::jsonb ELSE NULL END
        ),
        'info'
    );

    RETURN jsonb_build_object('success', true, 'id', v_id, 'action', v_action);
END;
$$;

-- Analytics with profile breakdown
CREATE OR REPLACE FUNCTION public.admin_get_spin_wheel_analytics()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
    v_overview jsonb;
    v_reward_stats jsonb;
    v_profile_stats jsonb;
    v_top_winners jsonb;
    v_active_users jsonb;
    v_suspicious jsonb;
    v_active_profile jsonb;
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;

    SELECT jsonb_build_object(
        'id', p.id,
        'slug', p.slug,
        'name', p.name,
        'expected_ev_ksp', public.compute_spin_profile_ev(p.id)
    ) INTO v_active_profile
    FROM public.spin_wheel_reward_profiles p
    WHERE p.is_active = true
    LIMIT 1;

    SELECT json_build_object(
        'total_spins', COUNT(*),
        'spins_today', COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE),
        'spins_this_month', COUNT(*) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)),
        'active_users', COUNT(DISTINCT user_id),
        'total_ksp_distributed', COALESCE(SUM((reward_json->>'points')::integer), 0),
        'daily_ksp', COALESCE(SUM((reward_json->>'points')::integer) FILTER (WHERE created_at >= CURRENT_DATE), 0),
        'monthly_ksp', COALESCE(SUM((reward_json->>'points')::integer) FILTER (WHERE created_at >= date_trunc('month', CURRENT_DATE)), 0),
        'active_profile', v_active_profile
    ) INTO v_overview
    FROM public.spin_history;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.win_count DESC), '[]'::jsonb)
    INTO v_reward_stats
    FROM (
        SELECT r.label, r.points, COUNT(sh.id) AS win_count,
            COALESCE(SUM((sh.reward_json->>'points')::integer), 0) AS total_ksp,
            ROUND(COUNT(sh.id)::numeric / NULLIF((SELECT COUNT(*) FROM public.spin_history), 0) * 100, 2) AS actual_win_pct
        FROM public.spin_wheel_rewards r
        LEFT JOIN public.spin_history sh ON sh.reward_id = r.id
        GROUP BY r.id, r.label, r.points
    ) t;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.spin_count DESC), '[]'::jsonb)
    INTO v_profile_stats
    FROM (
        SELECT
            COALESCE(sh.profile_slug, 'unknown') AS profile_slug,
            COALESCE(sh.profile_name, 'Unknown') AS profile_name,
            COUNT(*) AS spin_count,
            COALESCE(SUM((sh.reward_json->>'points')::integer), 0) AS total_ksp,
            ROUND(COUNT(*)::numeric / NULLIF((SELECT COUNT(*) FROM public.spin_history), 0) * 100, 2) AS pct_of_spins
        FROM public.spin_history sh
        GROUP BY sh.profile_slug, sh.profile_name
    ) t;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.total_won DESC), '[]'::jsonb)
    INTO v_top_winners
    FROM (
        SELECT sh.user_id, p.full_name, COUNT(*) AS spin_count,
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
        SELECT sh.user_id, p.full_name, COUNT(*) AS spin_count
        FROM public.spin_history sh
        LEFT JOIN public.profiles p ON p.id = sh.user_id
        GROUP BY sh.user_id, p.full_name
        ORDER BY spin_count DESC
        LIMIT 10
    ) t;

    SELECT COALESCE(jsonb_agg(row_to_json(t)::jsonb), '[]'::jsonb)
    INTO v_suspicious
    FROM (
        SELECT sh.user_id, p.full_name, COUNT(*) AS spins_last_hour,
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
        'profile_stats', v_profile_stats,
        'top_winners', v_top_winners,
        'most_active', v_active_users,
        'suspicious', v_suspicious
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_spin_reward_profiles() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_activate_spin_reward_profile(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_spin_profile_weight(uuid, uuid, integer) TO authenticated;
