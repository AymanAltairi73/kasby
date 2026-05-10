-- ============================================================
-- FIX: daily_check_in() - Use 24h interval instead of CURRENT_DATE
-- Run this in Supabase SQL Editor
-- ============================================================

DROP FUNCTION IF EXISTS public.daily_check_in() CASCADE;

CREATE OR REPLACE FUNCTION public.daily_check_in()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_last_checkin TIMESTAMPTZ;
    v_current_streak INTEGER := 1;
    v_points_to_award INTEGER := 10;
    v_next_check_in TIMESTAMPTZ;
    v_remaining_seconds INTEGER;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    -- Get last check-in time (server time)
    SELECT created_at INTO v_last_checkin
    FROM daily_check_ins WHERE user_id = v_user_id
    ORDER BY created_at DESC LIMIT 1;

    -- ✅ FIX: Use 24-hour interval from server time, not calendar date
    IF v_last_checkin IS NOT NULL AND (NOW() - v_last_checkin) < INTERVAL '24 hours' THEN
        v_next_check_in := v_last_checkin + INTERVAL '24 hours';
        v_remaining_seconds := GREATEST(0, EXTRACT(EPOCH FROM (v_next_check_in - NOW()))::INTEGER);
        RETURN json_build_object(
            'success', FALSE,
            'error', 'already_checked_in',
            'next_check_in_at', v_next_check_in,
            'remaining_seconds', v_remaining_seconds
        );
    END IF;

    -- Calculate streak: if last check-in was between 24-48 hours ago, continue streak
    IF v_last_checkin IS NOT NULL AND (NOW() - v_last_checkin) < INTERVAL '48 hours' THEN
        SELECT streak INTO v_current_streak
        FROM daily_check_ins WHERE user_id = v_user_id
        ORDER BY created_at DESC LIMIT 1;
        v_current_streak := v_current_streak + 1;
    END IF;

    -- Weekly bonus (every 7th day)
    IF v_current_streak % 7 = 0 THEN v_points_to_award := 50; END IF;

    -- Record check-in
    INSERT INTO daily_check_ins (user_id, streak, points_awarded)
    VALUES (v_user_id, v_current_streak, v_points_to_award);

    -- Record in point history
    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_user_id, v_points_to_award, 'earn', 'Daily check-in streak: ' || v_current_streak);

    -- Update user points
    INSERT INTO user_points (user_id, total_earned)
    VALUES (v_user_id, v_points_to_award)
    ON CONFLICT (user_id) DO UPDATE
    SET total_earned = user_points.total_earned + EXCLUDED.total_earned,
        updated_at = CURRENT_TIMESTAMP;

    -- Calculate next check-in time (24h from now)
    v_next_check_in := NOW() + INTERVAL '24 hours';

    RETURN json_build_object(
        'success', TRUE,
        'streak', v_current_streak,
        'points', v_points_to_award,
        'next_check_in_at', v_next_check_in
    );
END;
$$;

-- ============================================================
-- Helper function: get_check_in_status()
-- Called on view load to get server-side check-in state
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_check_in_status()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_last_checkin TIMESTAMPTZ;
    v_streak INTEGER := 0;
    v_can_check_in BOOLEAN := TRUE;
    v_next_check_in TIMESTAMPTZ;
    v_remaining_seconds INTEGER := 0;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT created_at, streak INTO v_last_checkin, v_streak
    FROM daily_check_ins WHERE user_id = v_user_id
    ORDER BY created_at DESC LIMIT 1;

    IF v_last_checkin IS NOT NULL AND (NOW() - v_last_checkin) < INTERVAL '24 hours' THEN
        v_can_check_in := FALSE;
        v_next_check_in := v_last_checkin + INTERVAL '24 hours';
        v_remaining_seconds := GREATEST(0, EXTRACT(EPOCH FROM (v_next_check_in - NOW()))::INTEGER);
    END IF;

    RETURN json_build_object(
        'success', TRUE,
        'can_check_in', v_can_check_in,
        'current_streak', COALESCE(v_streak, 0),
        'last_check_in', v_last_checkin,
        'next_check_in_at', v_next_check_in,
        'remaining_seconds', v_remaining_seconds
    );
END;
$$;
