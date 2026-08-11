-- ============================================================================
-- KASBY: Fix Missing 'title' Column in Supabase Schema
-- Date: 2026-08-12
-- Description: Resolves PostgrestException (code 42703: column "title" does not exist)
--              thrown during fn_cron_distribute_daily_profits execution.
-- ============================================================================

-- 1. Ensure 'title' column exists on notifications table
ALTER TABLE public.notifications 
ADD COLUMN IF NOT EXISTS title TEXT;

-- 2. Ensure 'title' column exists on transactions table
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS title TEXT;

-- 3. Ensure 'title' column exists on user_investments table
ALTER TABLE public.user_investments 
ADD COLUMN IF NOT EXISTS title TEXT;

-- 4. Ensure 'title' column exists on activity_logs table if used
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'activity_logs') THEN
        ALTER TABLE public.activity_logs ADD COLUMN IF NOT EXISTS title TEXT;
    END IF;
END $$;

-- 5. Verification Query: Confirm presence of 'title' in key tables
SELECT 
    table_name, 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name IN ('notifications', 'transactions', 'user_investments') 
  AND column_name = 'title';
