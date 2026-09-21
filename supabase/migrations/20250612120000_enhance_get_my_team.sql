-- Fix get_my_team: wrong column referred_by_id -> referred_by
-- Add hierarchical tree, friends, and aggregate stats.

CREATE OR REPLACE FUNCTION public.get_my_team()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_members json;
    v_friends json;
    v_tree json;
    v_referral_code TEXT;
    v_total INTEGER := 0;
    v_active INTEGER := 0;
    v_inactive INTEGER := 0;
    v_new_today INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT COALESCE(referral_code, '') INTO v_referral_code
    FROM profiles
    WHERE id = v_user_id;

    WITH RECURSIVE team_tree AS (
        SELECT
            p.id,
            p.full_name,
            p.avatar_url,
            p.created_at,
            p.status,
            p.referral_code,
            p.referred_by AS parent_id,
            1 AS level,
            ARRAY[p.id] AS path
        FROM profiles p
        WHERE p.referred_by = v_user_id

        UNION ALL

        SELECT
            p.id,
            p.full_name,
            p.avatar_url,
            p.created_at,
            p.status,
            p.referral_code,
            p.referred_by,
            tt.level + 1,
            tt.path || p.id
        FROM profiles p
        INNER JOIN team_tree tt ON p.referred_by = tt.id
        WHERE tt.level < 5
          AND NOT (p.id = ANY(tt.path))
    )
    SELECT COALESCE(
        json_agg(
            json_build_object(
                'id', t.id,
                'full_name', t.full_name,
                'avatar_url', t.avatar_url,
                'created_at', t.created_at,
                'status', t.status,
                'referral_code', t.referral_code,
                'parent_id', t.parent_id,
                'level', t.level,
                'member_type', 'referral',
                'direct_referrals', (
                    SELECT COUNT(*) FROM profiles WHERE referred_by = t.id
                )
            )
            ORDER BY t.level, t.created_at DESC
        ),
        '[]'::json
    )
    INTO v_tree
    FROM team_tree t;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json)
    INTO v_members
    FROM (
        SELECT
            p.id,
            p.full_name,
            p.avatar_url,
            p.created_at,
            p.status,
            (SELECT COUNT(*) FROM profiles WHERE referred_by = p.id) AS sub_referrals,
            p.referral_code,
            1 AS level,
            'referral' AS member_type
        FROM profiles p
        WHERE p.referred_by = v_user_id
        ORDER BY p.created_at DESC
    ) r;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json)
    INTO v_friends
    FROM (
        SELECT
            p.id,
            p.full_name,
            p.avatar_url,
            p.created_at,
            p.status,
            p.referral_code,
            f.created_at AS friends_since,
            'friend' AS member_type
        FROM friendships f
        JOIN profiles p ON p.id = CASE
            WHEN f.user_low_id = v_user_id THEN f.user_high_id
            ELSE f.user_low_id
        END
        WHERE f.user_low_id = v_user_id OR f.user_high_id = v_user_id
        ORDER BY f.created_at DESC
    ) r;

    SELECT
        COUNT(DISTINCT combined.id),
        COUNT(DISTINCT combined.id) FILTER (WHERE combined.status = 'active'),
        COUNT(DISTINCT combined.id) FILTER (WHERE combined.status <> 'active'),
        COUNT(DISTINCT combined.id) FILTER (WHERE combined.created_at >= CURRENT_DATE)
    INTO v_total, v_active, v_inactive, v_new_today
    FROM (
        SELECT p.id, p.status, p.created_at
        FROM profiles p
        WHERE p.referred_by = v_user_id

        UNION

        SELECT p.id, p.status, p.created_at
        FROM friendships f
        JOIN profiles p ON p.id = CASE
            WHEN f.user_low_id = v_user_id THEN f.user_high_id
            ELSE f.user_low_id
        END
        WHERE f.user_low_id = v_user_id OR f.user_high_id = v_user_id
    ) combined;

    RETURN json_build_object(
        'success', TRUE,
        'my_referral_code', COALESCE(v_referral_code, ''),
        'total_members', v_total,
        'active_members', v_active,
        'inactive_members', v_inactive,
        'new_today', v_new_today,
        'members', v_members,
        'friends', v_friends,
        'tree', v_tree
    );
END;
$$;
