-- Align daily_check_in with unified KSP reward credit path.

CREATE OR REPLACE FUNCTION public.daily_check_in()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_last_checkin timestamptz;
    v_current_streak integer := 1;
    v_points_to_award integer := 10;
    v_balance jsonb;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Unauthorized');
    END IF;

    PERFORM public.ensure_user_points(v_user_id);

    SELECT created_at, streak
      INTO v_last_checkin, v_current_streak
      FROM daily_check_ins
     WHERE user_id = v_user_id
     ORDER BY created_at DESC
     LIMIT 1;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE THEN
        RETURN json_build_object('success', false, 'error', 'Already checked in today');
    END IF;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE - INTERVAL '1 day' THEN
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    IF v_current_streak % 7 = 0 THEN
        v_points_to_award := 50;
    ELSIF v_current_streak % 3 = 0 THEN
        v_points_to_award := 25;
    END IF;

    INSERT INTO daily_check_ins (user_id, streak, points_awarded)
    VALUES (v_user_id, v_current_streak, v_points_to_award);

    v_balance := public.fn_credit_reward_ksp(
        v_user_id,
        v_points_to_award,
        'Daily check-in streak: ' || v_current_streak,
        NULL
    );

    RETURN json_build_object(
        'success', true,
        'streak', v_current_streak,
        'points_awarded', v_points_to_award,
        'effective_ksp', (v_balance->>'effective_ksp')::integer,
        'reward_ksp', (v_balance->>'reward_ksp')::integer,
        'wallet_ksp', (v_balance->>'wallet_ksp')::integer,
        'next_check_in_at', (CURRENT_DATE + INTERVAL '1 day')::timestamptz
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
