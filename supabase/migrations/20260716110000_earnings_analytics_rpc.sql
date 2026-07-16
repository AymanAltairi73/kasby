-- ============================================================================
-- Enterprise Earnings Analytics RPC
-- Server-authoritative aggregation of all earnings sources
-- ============================================================================
-- This RPC provides a complete analytics payload for earnings across:
-- - USD earnings from transactions table (profit, reward, investment_return)
-- - KSP earnings from point_history table (type = 'earn')
-- 
-- Key Design Principles:
-- - No hardcoded colors (Flutter handles theming)
-- - No localized labels (Flutter handles localization)
-- - No KSP conversion in SQL (Flutter uses CurrencyConversionService)
-- - All calculations server-side (percentages, totals, averages, highest-day)
-- - Single RPC call returns complete analytics payload
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_earnings_analytics(
  p_period TEXT DEFAULT 'today',
  p_start_date TIMESTAMPTZ DEFAULT NULL,
  p_end_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_start_date TIMESTAMPTZ;
  v_end_date TIMESTAMPTZ;
  v_timezone TEXT := 'UTC';
  
  -- Summary variables
  v_total_earnings_usd NUMERIC := 0;
  v_total_earnings_ksp INTEGER := 0;
  
  -- Statistics variables
  v_today_earnings_usd NUMERIC := 0;
  v_today_earnings_ksp INTEGER := 0;
  v_last_24h_earnings_usd NUMERIC := 0;
  v_last_24h_earnings_ksp INTEGER := 0;
  v_highest_daily_earnings_usd NUMERIC := 0;
  v_highest_daily_earnings_ksp INTEGER := 0;
  v_highest_earnings_date DATE;
  v_average_daily_earnings_usd NUMERIC := 0;
  v_days_in_period INTEGER := 0;
  
  -- Breakdown variables
  v_investments_usd NUMERIC := 0;
  v_lucky_wheel_ksp INTEGER := 0;
  v_referral_rewards_usd NUMERIC := 0;
  v_referral_rewards_ksp INTEGER := 0;
  v_registration_bonuses_usd NUMERIC := 0;
  v_registration_bonuses_ksp INTEGER := 0;
  v_other_rewards_usd NUMERIC := 0;
  v_other_rewards_ksp INTEGER := 0;
  v_investment_returns_usd NUMERIC := 0;
  
  -- Result JSONB
  v_result JSONB := '{}'::JSONB;
  v_breakdown JSONB := '[]'::JSONB;
  v_chart_data JSONB := '{}'::JSONB;
  v_timeline JSONB := '[]'::JSONB;
  v_trend_chart JSONB := '[]'::JSONB;
  
  -- Daily earnings for trend chart
  v_daily_earnings RECORD;
  
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authenticated');
  END IF;
  
  -- Calculate date range based on period (using UTC)
  CASE p_period
    WHEN 'today' THEN
      v_start_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC');
      v_end_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 day';
    WHEN 'last_24h' THEN
      v_start_date := NOW() - INTERVAL '24 hours';
      v_end_date := NOW();
    WHEN 'last_7d' THEN
      v_start_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') - INTERVAL '7 days';
      v_end_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 day';
    WHEN 'last_30d' THEN
      v_start_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') - INTERVAL '30 days';
      v_end_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 day';
    WHEN 'this_month' THEN
      v_start_date := DATE_TRUNC('month', NOW() AT TIME ZONE 'UTC');
      v_end_date := DATE_TRUNC('month', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 month';
    WHEN 'last_month' THEN
      v_start_date := DATE_TRUNC('month', NOW() AT TIME ZONE 'UTC') - INTERVAL '1 month';
      v_end_date := DATE_TRUNC('month', NOW() AT TIME ZONE 'UTC');
    WHEN 'custom' THEN
      v_start_date := COALESCE(p_start_date, DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC'));
      v_end_date := COALESCE(p_end_date, DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 day');
    ELSE
      -- Default to today
      v_start_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC');
      v_end_date := DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC') + INTERVAL '1 day';
  END CASE;
  
  -- Calculate days in period
  v_days_in_period := EXTRACT(DAY FROM (v_end_date - v_start_date))::INTEGER;
  IF v_days_in_period < 1 THEN v_days_in_period := 1; END IF;
  
  -- Aggregate USD earnings from transactions
  SELECT COALESCE(SUM(amount), 0) INTO v_investments_usd
  FROM transactions
  WHERE user_id = v_user_id
    AND type = 'profit'
    AND status = 'completed'
    AND created_at >= v_start_date
    AND created_at < v_end_date;
    
  SELECT COALESCE(SUM(amount), 0) INTO v_referral_rewards_usd
  FROM transactions
  WHERE user_id = v_user_id
    AND type = 'reward'
    AND status = 'completed'
    AND (description ILIKE '%إحالة%' OR description ILIKE '%referral%')
    AND created_at >= v_start_date
    AND created_at < v_end_date;
    
  SELECT COALESCE(SUM(amount), 0) INTO v_registration_bonuses_usd
  FROM transactions
  WHERE user_id = v_user_id
    AND type = 'reward'
    AND status = 'completed'
    AND (description ILIKE '%تسجيل%' OR description ILIKE '%registration%')
    AND created_at >= v_start_date
    AND created_at < v_end_date;
    
  SELECT COALESCE(SUM(amount), 0) INTO v_other_rewards_usd
  FROM transactions
  WHERE user_id = v_user_id
    AND type = 'reward'
    AND status = 'completed'
    AND NOT (description ILIKE '%إحالة%' OR description ILIKE '%referral%')
    AND NOT (description ILIKE '%تسجيل%' OR description ILIKE '%registration%')
    AND created_at >= v_start_date
    AND created_at < v_end_date;
    
  SELECT COALESCE(SUM(amount), 0) INTO v_investment_returns_usd
  FROM transactions
  WHERE user_id = v_user_id
    AND type = 'investment_return'
    AND status = 'completed'
    AND created_at >= v_start_date
    AND created_at < v_end_date;
  
  -- Aggregate KSP earnings from point_history
  SELECT COALESCE(SUM(points), 0) INTO v_lucky_wheel_ksp
  FROM point_history
  WHERE user_id = v_user_id
    AND type = 'earn'
    AND (description ILIKE '%spin%' OR description ILIKE '%wheel%' OR description ILIKE '%عجلة%')
    AND created_at >= v_start_date
    AND created_at < v_end_date;
    
  SELECT COALESCE(SUM(points), 0) INTO v_referral_rewards_ksp
  FROM point_history
  WHERE user_id = v_user_id
    AND type = 'earn'
    AND (description ILIKE '%referral%' OR description ILIKE '%إحالة%')
    AND NOT (description ILIKE '%registration%' OR description ILIKE '%تسجيل%')
    AND created_at >= v_start_date
    AND created_at < v_end_date;
    
  SELECT COALESCE(SUM(points), 0) INTO v_registration_bonuses_ksp
  FROM point_history
  WHERE user_id = v_user_id
    AND type = 'earn'
    AND (description ILIKE '%registration%' OR description ILIKE '%تسجيل%')
    AND created_at >= v_start_date
    AND created_at < v_end_date;
    
  SELECT COALESCE(SUM(points), 0) INTO v_other_rewards_ksp
  FROM point_history
  WHERE user_id = v_user_id
    AND type = 'earn'
    AND NOT (description ILIKE '%spin%' OR description ILIKE '%wheel%' OR description ILIKE '%عجلة%')
    AND NOT (description ILIKE '%referral%' OR description ILIKE '%إحالة%')
    AND NOT (description ILIKE '%registration%' OR description ILIKE '%تسجيل%')
    AND created_at >= v_start_date
    AND created_at < v_end_date;
  
  -- Calculate total earnings
  v_total_earnings_usd := v_investments_usd + v_referral_rewards_usd + v_registration_bonuses_usd + v_other_rewards_usd + v_investment_returns_usd;
  v_total_earnings_ksp := v_lucky_wheel_ksp + v_referral_rewards_ksp + v_registration_bonuses_ksp + v_other_rewards_ksp;
  
  -- Calculate today's earnings
  SELECT COALESCE(SUM(amount), 0) INTO v_today_earnings_usd
  FROM transactions
  WHERE user_id = v_user_id
    AND type IN ('profit', 'reward', 'investment_return')
    AND status = 'completed'
    AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE v_timezone) AT TIME ZONE 'UTC';
    
  SELECT COALESCE(SUM(points), 0) INTO v_today_earnings_ksp
  FROM point_history
  WHERE user_id = v_user_id
    AND type = 'earn'
    AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE v_timezone) AT TIME ZONE 'UTC';
  
  -- Calculate last 24h earnings
  SELECT COALESCE(SUM(amount), 0) INTO v_last_24h_earnings_usd
  FROM transactions
  WHERE user_id = v_user_id
    AND type IN ('profit', 'reward', 'investment_return')
    AND status = 'completed'
    AND created_at >= NOW() - INTERVAL '24 hours';
    
  SELECT COALESCE(SUM(points), 0) INTO v_last_24h_earnings_ksp
  FROM point_history
  WHERE user_id = v_user_id
    AND type = 'earn'
    AND created_at >= NOW() - INTERVAL '24 hours';
  
  -- Calculate highest daily earnings within period
  SELECT COALESCE(daily_total, 0) INTO v_highest_daily_earnings_usd
  FROM (
    SELECT 
      DATE_TRUNC('day', created_at AT TIME ZONE v_timezone) as day,
      SUM(amount) as daily_total
    FROM transactions
    WHERE user_id = v_user_id
      AND type IN ('profit', 'reward', 'investment_return')
      AND status = 'completed'
      AND created_at >= v_start_date
      AND created_at < v_end_date
    GROUP BY day
    ORDER BY daily_total DESC
    LIMIT 1
  ) subquery;
  
  SELECT day INTO v_highest_earnings_date
  FROM (
    SELECT 
      DATE_TRUNC('day', created_at AT TIME ZONE v_timezone) as day,
      SUM(amount) as daily_total
    FROM transactions
    WHERE user_id = v_user_id
      AND type IN ('profit', 'reward', 'investment_return')
      AND status = 'completed'
      AND created_at >= v_start_date
      AND created_at < v_end_date
    GROUP BY day
    ORDER BY daily_total DESC
    LIMIT 1
  ) subquery;
  
  -- Calculate average daily earnings (including zero-earnings days)
  v_average_daily_earnings_usd := v_total_earnings_usd / v_days_in_period;
  
  -- Build breakdown array (stable source keys, no localized labels)
  IF v_investments_usd > 0 THEN
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'investments',
      'amount_usd', v_investments_usd,
      'amount_ksp', NULL::INTEGER,
      'percentage', CASE WHEN v_total_earnings_usd > 0 THEN ROUND((v_investments_usd / v_total_earnings_usd * 100), 2) ELSE 0 END
    );
  END IF;
  
  IF v_lucky_wheel_ksp > 0 THEN
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'lucky_wheel',
      'amount_usd', 0,
      'amount_ksp', v_lucky_wheel_ksp,
      'percentage', 0 -- Will be calculated in Flutter after KSP conversion
    );
  END IF;
  
  IF v_referral_rewards_usd > 0 OR v_referral_rewards_ksp > 0 THEN
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'referral_rewards',
      'amount_usd', v_referral_rewards_usd,
      'amount_ksp', v_referral_rewards_ksp,
      'percentage', CASE WHEN v_total_earnings_usd > 0 THEN ROUND((v_referral_rewards_usd / v_total_earnings_usd * 100), 2) ELSE 0 END
    );
  END IF;
  
  IF v_registration_bonuses_usd > 0 OR v_registration_bonuses_ksp > 0 THEN
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'registration_bonuses',
      'amount_usd', v_registration_bonuses_usd,
      'amount_ksp', v_registration_bonuses_ksp,
      'percentage', CASE WHEN v_total_earnings_usd > 0 THEN ROUND((v_registration_bonuses_usd / v_total_earnings_usd * 100), 2) ELSE 0 END
    );
  END IF;
  
  IF v_other_rewards_usd > 0 OR v_other_rewards_ksp > 0 THEN
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'other_rewards',
      'amount_usd', v_other_rewards_usd,
      'amount_ksp', v_other_rewards_ksp,
      'percentage', CASE WHEN v_total_earnings_usd > 0 THEN ROUND((v_other_rewards_usd / v_total_earnings_usd * 100), 2) ELSE 0 END
    );
  END IF;
  
  IF v_investment_returns_usd > 0 THEN
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'investment_returns',
      'amount_usd', v_investment_returns_usd,
      'amount_ksp', NULL::INTEGER,
      'percentage', CASE WHEN v_total_earnings_usd > 0 THEN ROUND((v_investment_returns_usd / v_total_earnings_usd * 100), 2) ELSE 0 END
    );
  END IF;
  
  -- Build timeline (chronological earnings history)
  FOR v_daily_earnings IN
    SELECT 
      id,
      CASE 
        WHEN type = 'profit' THEN 'investments'
        WHEN type = 'reward' AND (description ILIKE '%إحالة%' OR description ILIKE '%referral%') THEN 'referral_rewards'
        WHEN type = 'reward' AND (description ILIKE '%تسجيل%' OR description ILIKE '%registration%') THEN 'registration_bonuses'
        WHEN type = 'reward' THEN 'other_rewards'
        WHEN type = 'investment_return' THEN 'investment_returns'
        ELSE 'other_rewards'
      END as source,
      amount as amount_usd,
      NULL::INTEGER as amount_ksp,
      description,
      created_at
    FROM transactions
    WHERE user_id = v_user_id
      AND type IN ('profit', 'reward', 'investment_return')
      AND status = 'completed'
      AND created_at >= v_start_date
      AND created_at < v_end_date
    ORDER BY created_at DESC
  LOOP
    v_timeline := v_timeline || jsonb_build_object(
      'id', v_daily_earnings.id,
      'source', v_daily_earnings.source,
      'amount_usd', v_daily_earnings.amount_usd,
      'amount_ksp', v_daily_earnings.amount_ksp,
      'description', v_daily_earnings.description,
      'created_at', v_daily_earnings.created_at
    );
  END LOOP;
  
  -- Add KSP earnings to timeline
  FOR v_daily_earnings IN
    SELECT 
      id,
      CASE 
        WHEN description ILIKE '%spin%' OR description ILIKE '%wheel%' OR description ILIKE '%عجلة%' THEN 'lucky_wheel'
        WHEN description ILIKE '%referral%' OR description ILIKE '%إحالة%' THEN 'referral_rewards'
        WHEN description ILIKE '%registration%' OR description ILIKE '%تسجيل%' THEN 'registration_bonuses'
        ELSE 'other_rewards'
      END as source,
      0 as amount_usd,
      points as amount_ksp,
      description,
      created_at
    FROM point_history
    WHERE user_id = v_user_id
      AND type = 'earn'
      AND created_at >= v_start_date
      AND created_at < v_end_date
    ORDER BY created_at DESC
  LOOP
    v_timeline := v_timeline || jsonb_build_object(
      'id', v_daily_earnings.id,
      'source', v_daily_earnings.source,
      'amount_usd', v_daily_earnings.amount_usd,
      'amount_ksp', v_daily_earnings.amount_ksp,
      'description', v_daily_earnings.description,
      'created_at', v_daily_earnings.created_at
    );
  END LOOP;
  
  -- Build 7-day trend chart
  FOR i IN 0..6 LOOP
    DECLARE
      v_day_start TIMESTAMPTZ;
      v_day_end TIMESTAMPTZ;
      v_day_earnings_usd NUMERIC := 0;
      v_day_date DATE;
    BEGIN
      v_day_start := (DATE_TRUNC('day', NOW() AT TIME ZONE v_timezone) - (i || ' days')::INTERVAL) AT TIME ZONE 'UTC';
      v_day_end := v_day_start + INTERVAL '1 day';
      v_day_date := DATE(v_day_start AT TIME ZONE v_timezone);
      
      SELECT COALESCE(SUM(amount), 0) INTO v_day_earnings_usd
      FROM transactions
      WHERE user_id = v_user_id
        AND type IN ('profit', 'reward', 'investment_return')
        AND status = 'completed'
        AND created_at >= v_day_start
        AND created_at < v_day_end;
      
      v_trend_chart := jsonb_build_object(
        'date', v_day_date,
        'amount_usd', v_day_earnings_usd
      ) || v_trend_chart;
    END;
  END LOOP;
  
  -- Build chart data (no colors, stable source keys)
  v_chart_data := jsonb_build_object(
    'trend_chart', v_trend_chart
  );
  
  -- Build final result
  v_result := jsonb_build_object(
    'success', true,
    'summary', jsonb_build_object(
      'total_earnings_usd', v_total_earnings_usd,
      'total_earnings_ksp', v_total_earnings_ksp,
      'period_start', v_start_date,
      'period_end', v_end_date,
      'period', p_period
    ),
    'statistics', jsonb_build_object(
      'total_earnings_usd', v_total_earnings_usd,
      'total_earnings_ksp', v_total_earnings_ksp,
      'today_earnings_usd', v_today_earnings_usd,
      'today_earnings_ksp', v_today_earnings_ksp,
      'last_24h_earnings_usd', v_last_24h_earnings_usd,
      'last_24h_earnings_ksp', v_last_24h_earnings_ksp,
      'highest_daily_earnings_usd', v_highest_daily_earnings_usd,
      'highest_earnings_date', v_highest_earnings_date,
      'average_daily_earnings_usd', v_average_daily_earnings_usd,
      'days_in_period', v_days_in_period
    ),
    'breakdown', v_breakdown,
    'chart_data', v_chart_data,
    'timeline', v_timeline
  );
  
  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_earnings_analytics(TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;
