-- Recurring investments table
CREATE TABLE IF NOT EXISTS public.recurring_investments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.investment_plans(id),
  plan_name text,
  amount numeric(15,2) NOT NULL CHECK (amount > 0),
  frequency text NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'custom')),
  custom_days integer CHECK (custom_days > 0 OR frequency != 'custom'),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'cancelled')),
  next_execution_date timestamptz,
  last_execution_date timestamptz,
  total_executions integer DEFAULT 0,
  successful_executions integer DEFAULT 0,
  failed_executions integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_recurring_investments_user 
  ON public.recurring_investments(user_id);
CREATE INDEX IF NOT EXISTS idx_recurring_investments_next_exec 
  ON public.recurring_investments(next_execution_date) 
  WHERE status = 'active';

-- RLS
ALTER TABLE public.recurring_investments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_manage_own_recurring" ON public.recurring_investments
  FOR ALL USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.update_recurring_investment_timestamp()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_recurring_investments_updated
  BEFORE UPDATE ON public.recurring_investments
  FOR EACH ROW EXECUTE FUNCTION public.update_recurring_investment_timestamp();

-- RPC: Execute a single recurring investment
-- Called by pg_cron or edge function
CREATE OR REPLACE FUNCTION public.execute_recurring_investment(p_recurring_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rec record;
  v_result jsonb;
  v_next_date timestamptz;
  v_idempotency_key text;
BEGIN
  -- Lock the row
  SELECT * INTO v_rec FROM public.recurring_investments
    WHERE id = p_recurring_id AND status = 'active'
    FOR UPDATE SKIP LOCKED;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Recurring investment not found or not active');
  END IF;
  
  -- Check if it's time to execute
  IF v_rec.next_execution_date > now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not yet due for execution');
  END IF;
  
  -- Generate idempotency key
  v_idempotency_key := 'recurring_' || p_recurring_id || '_' || to_char(now(), 'YYYYMMDD_HH24MISS');
  
  -- Call the existing create_investment RPC
  BEGIN
    v_result := public.create_investment(
      p_user_id := v_rec.user_id,
      p_plan_id := v_rec.plan_id,
      p_amount := v_rec.amount,
      p_idempotency_key := v_idempotency_key
    );
  EXCEPTION WHEN OTHERS THEN
    -- Log failure and increment counter
    UPDATE public.recurring_investments SET
      failed_executions = failed_executions + 1,
      last_execution_date = now()
    WHERE id = p_recurring_id;
    
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
  END;
  
  -- Calculate next execution date
  v_next_date := CASE v_rec.frequency
    WHEN 'daily' THEN now() + interval '1 day'
    WHEN 'weekly' THEN now() + interval '7 days'
    WHEN 'monthly' THEN now() + interval '1 month'
    WHEN 'custom' THEN now() + (v_rec.custom_days || ' days')::interval
  END;
  
  -- Update recurring record
  UPDATE public.recurring_investments SET
    total_executions = total_executions + 1,
    successful_executions = successful_executions + 1,
    last_execution_date = now(),
    next_execution_date = v_next_date
  WHERE id = p_recurring_id;
  
  RETURN jsonb_build_object('success', true, 'investment_result', v_result, 'next_execution', v_next_date);
END;
$$;

-- RPC: Process all due recurring investments (called by pg_cron)
CREATE OR REPLACE FUNCTION public.process_due_recurring_investments()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rec record;
  v_results jsonb[] := '{}';
  v_result jsonb;
BEGIN
  FOR v_rec IN 
    SELECT id FROM public.recurring_investments
    WHERE status = 'active'
      AND next_execution_date <= now()
    ORDER BY next_execution_date ASC
    LIMIT 100
  LOOP
    v_result := public.execute_recurring_investment(v_rec.id);
    v_results := array_append(v_results, jsonb_build_object('id', v_rec.id, 'result', v_result));
  END LOOP;
  
  RETURN jsonb_build_object(
    'success', true,
    'processed', array_length(v_results, 1),
    'results', to_jsonb(v_results)
  );
END;
$$;

-- pg_cron: Schedule recurring investment execution every hour
-- NOTE: This requires pg_cron extension enabled in Supabase dashboard
-- SELECT cron.schedule(
--   'process-recurring-investments',
--   '0 * * * *',  -- Every hour
--   $$SELECT public.process_due_recurring_investments()$$
-- );
