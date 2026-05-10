-- ─── HARDENING GET_MY_TEAM RPC ──────────────────────────────────────────
-- Ensures that the referral code is always returned if available, 
-- and handles the case where it might be NULL in the profiles table.

CREATE OR REPLACE FUNCTION public.get_my_team()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_members json;
    v_total_count INTEGER;
    v_referral_code TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    -- [1] Get user's referral code with fallback
    -- We use COALESCE to ensure we don't return null if the column exists but is empty
    SELECT COALESCE(referral_code, '') INTO v_referral_code 
    FROM profiles 
    WHERE id = v_user_id;

    -- [2] Count total team members (Level 1 only)
    SELECT COUNT(*) INTO v_total_count
    FROM profiles WHERE referred_by_id = v_user_id;

    -- [3] Get team members with their sub-referral counts
    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_members
    FROM (
        SELECT p.id, p.full_name, p.avatar_url, p.created_at, p.status,
               (SELECT COUNT(*) FROM profiles WHERE referred_by_id = p.id) AS sub_referrals,
               p.referral_code -- Also include member's own code if needed for future UI
        FROM profiles p
        WHERE p.referred_by_id = v_user_id
        ORDER BY p.created_at DESC
    ) r;

    RETURN json_build_object(
        'success', TRUE,
        'my_referral_code', COALESCE(v_referral_code, ''),
        'total_members', v_total_count,
        'members', v_members
    );
END;
$$;
