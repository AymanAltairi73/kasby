-- ============================================================
-- FIX: Update tier check constraint and the RPC
-- ============================================================

-- 1. Update the constraint to allow 'free'
ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_tier_check;
ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_tier_check CHECK (tier IN ('free', 'verified', 'vip', 'premium'));

-- 2. (Optional but recommended) Update the activate_free_plan function if needed
CREATE OR REPLACE FUNCTION activate_free_plan()
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_last_end TIMESTAMPTZ;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'غير مسجل الدخول');
  END IF;

  -- Get the end date of the latest free subscription
  SELECT end_date INTO v_last_end
  FROM public.subscriptions
  WHERE user_id = v_user_id AND tier = 'free'
  ORDER BY end_date DESC
  LIMIT 1;

  -- Check if there is an active free plan
  IF v_last_end IS NOT NULL AND v_last_end > NOW() THEN
    RETURN jsonb_build_object(
        'success', false, 
        'error', 'الخطة المجانية نشطة بالفعل وتنتهي في ' || v_last_end::TEXT
    );
  END IF;

  -- Expire any previous active subscriptions for this user
  UPDATE public.subscriptions 
  SET status = 'expired' 
  WHERE user_id = v_user_id AND status = 'active';

  -- Create new free subscription for 24 hours
  INSERT INTO public.subscriptions (
      user_id, 
      tier, 
      is_yearly, 
      status, 
      start_date, 
      end_date, 
      price
  )
  VALUES (
    v_user_id,
    'free',
    false,
    'active',
    NOW(),
    NOW() + INTERVAL '24 hours',
    0
  );

  -- Update profile tier to 'free'
  UPDATE public.profiles 
  SET account_tier = 'free' 
  WHERE id = v_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'تم تفعيل الخطة المجانية بنجاح لمدة 24 ساعة',
    'end_date', NOW() + INTERVAL '24 hours'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Procedure to check for expiring subscriptions and notify
-- This can be called by a Supabase Cron or triggered via Edge Function
CREATE OR REPLACE FUNCTION notify_expiring_subscriptions()
RETURNS VOID AS $$
BEGIN
    -- Insert notifications for subscriptions expiring in the next hour that haven't been notified yet
    -- (Assuming we add a 'notified_expiry' column to subscriptions, or just use a grace period)
    INSERT INTO public.notifications (user_id, title, message)
    SELECT 
        s.user_id,
        CASE WHEN s.tier = 'free' THEN 'انتهت الفترة المجانية' ELSE 'قرب انتهاء الاشتراك' END,
        CASE 
            WHEN s.tier = 'free' THEN 'لقد انتهت الـ 24 ساعة الماضية، هل تود تفعيل الفترة المجانية مرة أخرى أم الترقية للـ VIP؟'
            ELSE 'اشتراكك الـ ' || s.tier || ' سينتهي قريباً. يرجى التجديد للاستمرار في الحصول على الميزات.'
        END
    FROM public.subscriptions s
    WHERE s.status = 'active' 
      AND s.end_date <= NOW()
      AND NOT EXISTS (
          SELECT 1 FROM public.notifications n 
          WHERE n.user_id = s.user_id 
            AND n.created_at >= NOW() - INTERVAL '1 hour'
            AND (n.title = 'انتهت الفترة المجانية' OR n.title = 'قرب انتهاء الاشتراك')
      );

    -- Mark expired subscriptions
    UPDATE public.subscriptions 
    SET status = 'expired' 
    WHERE status = 'active' AND end_date <= NOW();
END;
$$ LANGUAGE plpgsql;
