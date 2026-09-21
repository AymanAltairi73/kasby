-- =============================================================================
-- Kasby Social Network Enterprise Redesign
-- Removes arbitrary global friend-request cooldown; adds intelligent abuse
-- protection, enriched RPCs, realtime publication, and social notifications.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Realtime publication for social tables
-- ---------------------------------------------------------------------------
ALTER TABLE public.friend_requests REPLICA IDENTITY FULL;
ALTER TABLE public.friendships REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'friend_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_requests;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'friendships'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.friendships;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Helper: mutual friends count
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_mutual_friends_count(p_user_a UUID, p_user_b UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*)::INTEGER INTO v_count
  FROM (
    SELECT CASE WHEN f.user_low_id = p_user_a THEN f.user_high_id ELSE f.user_low_id END AS friend_id
    FROM friendships f
    WHERE f.user_low_id = p_user_a OR f.user_high_id = p_user_a
    INTERSECT
    SELECT CASE WHEN f.user_low_id = p_user_b THEN f.user_high_id ELSE f.user_low_id END AS friend_id
    FROM friendships f
    WHERE f.user_low_id = p_user_b OR f.user_high_id = p_user_b
  ) mutual;
  RETURN COALESCE(v_count, 0);
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. send_friend_request — remove global 60s limit; intelligent abuse guard
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_friend_request(p_receiver_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_requester_id UUID := auth.uid();
  v_recent_count INTEGER;
  v_per_recipient_recent TIMESTAMPTZ;
BEGIN
  IF v_requester_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  IF v_requester_id = p_receiver_id THEN
    RETURN json_build_object('success', FALSE, 'error', 'cannot_add_self');
  END IF;

  -- Block inactive / suspended accounts from sending
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = v_requester_id AND status NOT IN ('active', 'verified')
  ) THEN
    RETURN json_build_object('success', FALSE, 'error', 'account_restricted');
  END IF;

  -- Already friends
  IF EXISTS (
    SELECT 1 FROM friendships
    WHERE user_low_id = LEAST(v_requester_id, p_receiver_id)
      AND user_high_id = GREATEST(v_requester_id, p_receiver_id)
  ) THEN
    RETURN json_build_object('success', FALSE, 'error', 'already_friends');
  END IF;

  -- Duplicate pending outbound
  IF EXISTS (
    SELECT 1 FROM friend_requests
    WHERE requester_id = v_requester_id
      AND receiver_id = p_receiver_id
      AND status = 'pending'
  ) THEN
    RETURN json_build_object('success', FALSE, 'error', 'request_already_pending');
  END IF;

  -- Per-recipient debounce (3 seconds) — prevents double-tap only
  SELECT MAX(created_at) INTO v_per_recipient_recent
  FROM friend_requests
  WHERE requester_id = v_requester_id
    AND receiver_id = p_receiver_id
    AND created_at > NOW() - INTERVAL '3 seconds';

  IF v_per_recipient_recent IS NOT NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'request_too_fast');
  END IF;

  -- Intelligent abuse detection: max 100 new requests per rolling hour
  SELECT COUNT(*) INTO v_recent_count
  FROM friend_requests
  WHERE requester_id = v_requester_id
    AND created_at > NOW() - INTERVAL '1 hour';

  IF v_recent_count >= 100 THEN
    RETURN json_build_object('success', FALSE, 'error', 'abuse_rate_limit');
  END IF;

  -- Reverse request auto-accept
  IF EXISTS (
    SELECT 1 FROM friend_requests
    WHERE requester_id = p_receiver_id
      AND receiver_id = v_requester_id
      AND status = 'pending'
  ) THEN
    UPDATE friend_requests SET status = 'accepted', updated_at = NOW()
    WHERE requester_id = p_receiver_id AND receiver_id = v_requester_id;

    INSERT INTO friendships (user_low_id, user_high_id)
    VALUES (LEAST(v_requester_id, p_receiver_id), GREATEST(v_requester_id, p_receiver_id))
    ON CONFLICT DO NOTHING;

    RETURN json_build_object('success', TRUE, 'auto_accepted', TRUE);
  END IF;

  INSERT INTO friend_requests (requester_id, receiver_id)
  VALUES (v_requester_id, p_receiver_id);

  RETURN json_build_object('success', TRUE);
END;
$$;

-- Add updated_at to friend_requests if missing
ALTER TABLE public.friend_requests
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- ---------------------------------------------------------------------------
-- 4. Enriched friend RPCs
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_friend_requests()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_result json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
  FROM (
    SELECT
      fr.id AS request_id,
      fr.requester_id,
      fr.created_at,
      p.full_name,
      p.avatar_url,
      p.referral_code AS username,
      p.last_seen_at,
      public.fn_mutual_friends_count(v_user_id, fr.requester_id) AS mutual_friends
    FROM friend_requests fr
    JOIN profiles p ON p.id = fr.requester_id
    WHERE fr.receiver_id = v_user_id AND fr.status = 'pending'
    ORDER BY fr.created_at DESC
  ) r;

  RETURN json_build_object('success', TRUE, 'requests', v_result);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_outgoing_friend_requests()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_result json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
  FROM (
    SELECT
      fr.id AS request_id,
      fr.receiver_id,
      fr.created_at,
      p.full_name,
      p.avatar_url,
      p.referral_code AS username,
      p.last_seen_at,
      public.fn_mutual_friends_count(v_user_id, fr.receiver_id) AS mutual_friends
    FROM friend_requests fr
    JOIN profiles p ON p.id = fr.receiver_id
    WHERE fr.requester_id = v_user_id AND fr.status = 'pending'
    ORDER BY fr.created_at DESC
  ) r;

  RETURN json_build_object('success', TRUE, 'requests', v_result);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_friends()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_result json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
  FROM (
    SELECT
      p.id,
      p.full_name,
      p.avatar_url,
      p.referral_code AS username,
      p.last_seen_at,
      f.created_at AS friends_since
    FROM friendships f
    JOIN profiles p ON p.id = CASE
      WHEN f.user_low_id = v_user_id THEN f.user_high_id
      ELSE f.user_low_id
    END
    WHERE f.user_low_id = v_user_id OR f.user_high_id = v_user_id
    ORDER BY f.created_at DESC
  ) r;

  RETURN json_build_object('success', TRUE, 'friends', v_result);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_friend_suggestions(p_limit INTEGER DEFAULT 20)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_result json;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
  FROM (
    SELECT
      p.id,
      p.full_name,
      p.avatar_url,
      p.referral_code AS username,
      p.last_seen_at,
      public.fn_mutual_friends_count(v_user_id, p.id) AS mutual_friends
    FROM profiles p
    WHERE p.id != v_user_id
      AND p.role = 'user'
      AND p.status IN ('active', 'verified')
      AND NOT EXISTS (
        SELECT 1 FROM friendships
        WHERE user_low_id = LEAST(v_user_id, p.id)
          AND user_high_id = GREATEST(v_user_id, p.id)
      )
      AND NOT EXISTS (
        SELECT 1 FROM friend_requests
        WHERE (
          (requester_id = v_user_id AND receiver_id = p.id)
          OR (requester_id = p.id AND receiver_id = v_user_id)
        ) AND status = 'pending'
      )
    ORDER BY mutual_friends DESC, p.full_name ASC
    LIMIT LEAST(GREATEST(p_limit, 1), 50)
  ) r;

  RETURN json_build_object('success', TRUE, 'suggestions', v_result);
END;
$$;

CREATE OR REPLACE FUNCTION public.search_social_users(
  p_query TEXT,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_result json;
  v_total INTEGER;
  v_clean TEXT := TRIM(COALESCE(p_query, ''));
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  IF LENGTH(v_clean) < 2 THEN
    RETURN json_build_object('success', FALSE, 'error', 'query_too_short');
  END IF;

  SELECT COUNT(*) INTO v_total
  FROM profiles p
  WHERE p.id != v_user_id
    AND p.role = 'user'
    AND p.status IN ('active', 'verified')
    AND (
      p.full_name ILIKE '%' || v_clean || '%'
      OR p.referral_code ILIKE '%' || v_clean || '%'
    );

  SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_result
  FROM (
    SELECT
      p.id,
      p.full_name,
      p.avatar_url,
      p.referral_code AS username,
      p.last_seen_at,
      public.fn_mutual_friends_count(v_user_id, p.id) AS mutual_friends,
      EXISTS (
        SELECT 1 FROM friendships
        WHERE user_low_id = LEAST(v_user_id, p.id)
          AND user_high_id = GREATEST(v_user_id, p.id)
      ) AS is_friend,
      EXISTS (
        SELECT 1 FROM friend_requests
        WHERE requester_id = v_user_id AND receiver_id = p.id AND status = 'pending'
      ) AS request_sent,
      EXISTS (
        SELECT 1 FROM friend_requests
        WHERE requester_id = p.id AND receiver_id = v_user_id AND status = 'pending'
      ) AS request_received
    FROM profiles p
    WHERE p.id != v_user_id
      AND p.role = 'user'
      AND p.status IN ('active', 'verified')
      AND (
        p.full_name ILIKE '%' || v_clean || '%'
        OR p.referral_code ILIKE '%' || v_clean || '%'
      )
    ORDER BY
      CASE WHEN p.referral_code ILIKE v_clean THEN 0 ELSE 1 END,
      p.full_name ASC
    LIMIT LEAST(GREATEST(p_limit, 1), 50)
    OFFSET GREATEST(p_offset, 0)
  ) r;

  RETURN json_build_object(
    'success', TRUE,
    'users', v_result,
    'total', v_total,
    'limit', p_limit,
    'offset', p_offset
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_social_dashboard_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_total_friends INTEGER;
  v_pending_incoming INTEGER;
  v_pending_outgoing INTEGER;
  v_new_friends_today INTEGER;
  v_messages_today INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  SELECT COUNT(*) INTO v_total_friends
  FROM friendships
  WHERE user_low_id = v_user_id OR user_high_id = v_user_id;

  SELECT COUNT(*) INTO v_pending_incoming
  FROM friend_requests
  WHERE receiver_id = v_user_id AND status = 'pending';

  SELECT COUNT(*) INTO v_pending_outgoing
  FROM friend_requests
  WHERE requester_id = v_user_id AND status = 'pending';

  SELECT COUNT(*) INTO v_new_friends_today
  FROM friendships
  WHERE (user_low_id = v_user_id OR user_high_id = v_user_id)
    AND created_at >= CURRENT_DATE;

  SELECT COUNT(*) INTO v_messages_today
  FROM chat_messages cm
  JOIN chat_conversations cc ON cc.id = cm.conversation_id
  WHERE cc.category = 'social'
    AND (cc.user_low_id = v_user_id OR cc.user_high_id = v_user_id)
    AND cm.sender_id = v_user_id
    AND cm.created_at >= CURRENT_DATE;

  RETURN json_build_object(
    'success', TRUE,
    'total_friends', v_total_friends,
    'pending_incoming', v_pending_incoming,
    'pending_outgoing', v_pending_outgoing,
    'new_friends_today', v_new_friends_today,
    'messages_today', v_messages_today
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. remove_friend with notification
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.remove_friend(p_friend_id UUID)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_remover_name TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', FALSE, 'error', 'unauthorized');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM friendships
    WHERE user_low_id = LEAST(v_user_id, p_friend_id)
      AND user_high_id = GREATEST(v_user_id, p_friend_id)
  ) THEN
    RETURN json_build_object('success', FALSE, 'error', 'not_friends');
  END IF;

  SELECT full_name INTO v_remover_name FROM profiles WHERE id = v_user_id;

  DELETE FROM friendships
  WHERE user_low_id = LEAST(v_user_id, p_friend_id)
    AND user_high_id = GREATEST(v_user_id, p_friend_id);

  DELETE FROM friend_requests
  WHERE (requester_id = v_user_id AND receiver_id = p_friend_id)
     OR (requester_id = p_friend_id AND receiver_id = v_user_id);

  -- Notify removed friend (dedupe: skip if same notification in last 5 min)
  IF NOT EXISTS (
    SELECT 1 FROM notifications
    WHERE user_id = p_friend_id
      AND type = 'social_friend_removed'
      AND target_user_id = v_user_id
      AND created_at > NOW() - INTERVAL '5 minutes'
  ) THEN
    INSERT INTO notifications (user_id, title, message, target, target_user_id, type)
    VALUES (
      p_friend_id,
      'تمت إزالة الصداقة',
      'قام ' || COALESCE(v_remover_name, 'مستخدم') || ' بإزالتك من قائمة أصدقائه.',
      'social',
      v_user_id,
      'social_friend_removed'
    );
  END IF;

  RETURN json_build_object('success', TRUE);
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. Notification trigger — dedupe friend request notifications
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_name TEXT;
BEGIN
  SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.requester_id;

  IF TG_OP = 'INSERT' THEN
    IF NOT EXISTS (
      SELECT 1 FROM notifications
      WHERE user_id = NEW.receiver_id
        AND type = 'social_friend_request'
        AND target_user_id = NEW.requester_id
        AND created_at > NOW() - INTERVAL '5 minutes'
    ) THEN
      INSERT INTO notifications (user_id, title, message, target, target_user_id, type)
      VALUES (
        NEW.receiver_id,
        'طلب صداقة جديد',
        'أرسل لك ' || COALESCE(v_sender_name, 'مستخدم') || ' طلب صداقة.',
        'social',
        NEW.requester_id,
        'social_friend_request'
      );
    END IF;
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    SELECT full_name INTO v_sender_name FROM profiles WHERE id = NEW.receiver_id;
    IF NOT EXISTS (
      SELECT 1 FROM notifications
      WHERE user_id = NEW.requester_id
        AND type = 'social_friend_accepted'
        AND target_user_id = NEW.receiver_id
        AND created_at > NOW() - INTERVAL '5 minutes'
    ) THEN
      INSERT INTO notifications (user_id, title, message, target, target_user_id, type)
      VALUES (
        NEW.requester_id,
        'تم قبول طلب الصداقة',
        'وافق ' || COALESCE(v_sender_name, 'مستخدم') || ' على طلب صداقتك.',
        'social',
        NEW.receiver_id,
        'social_friend_accepted'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Extend notifications type check for social_friend_removed
DO $$
BEGIN
  ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
  ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (
    type IS NULL OR type = ANY (ARRAY[
      'deposit_submitted','deposit_approved','deposit_rejected',
      'withdrawal_requested','withdrawal_approved','withdrawal_rejected','withdrawal_completed',
      'transfer_received','transfer_sent',
      'loan_requested','loan_approved','loan_rejected','loan_repayment_due','loan_overdue','loan_paid',
      'investment_created','daily_profit','investment_matured','investment_cancelled',
      'chat_new_message','chat_admin_reply','chat_resolved','chat_escalated',
      'kyc_approved','kyc_rejected',
      'account_flagged','account_frozen','account_unblocked','profile_updated','account_deleted',
      'role_upgraded','referral_bonus','reward',
      'agent_deposit_pending','agent_withdrawal_pending','agent_role_change',
      'admin_kyc_pending','admin_deposit_pending','admin_withdrawal_pending',
      'marketplace_order','marketplace_reward',
      'social_friend_request','social_friend_accepted','social_friend_removed','social_chat',
      'financial_transfer','financial_deposit','financial_withdrawal','financial_loan',
      'otp_verification','system','security_alert'
    ]::text[])
  );
EXCEPTION WHEN others THEN
  NULL;
END $$;

-- Grants
GRANT EXECUTE ON FUNCTION public.get_outgoing_friend_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_social_users(TEXT, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_social_dashboard_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_mutual_friends_count(UUID, UUID) TO authenticated;
