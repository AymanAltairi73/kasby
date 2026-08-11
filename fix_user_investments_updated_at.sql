-- ============================================================================
-- KASBY: Fix Missing updated_at Column on user_investments Table
-- Date: 2026-08-12
-- Description: Resolves PostgrestException (code 42703: column "updated_at" of 
--              relation "user_investments" does not exist) thrown during RPC
--              fn_cron_distribute_daily_profits execution.
-- ============================================================================

-- 1. Add updated_at column to user_investments table if it does not exist
ALTER TABLE public.user_investments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Backfill updated_at with created_at or NOW() for existing records
UPDATE public.user_investments 
SET updated_at = COALESCE(created_at, NOW()) 
WHERE updated_at IS NULL;

-- 3. Create or replace trigger function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Attach trigger to user_investments table
DROP TRIGGER IF EXISTS trg_user_investments_updated_at ON public.user_investments;
CREATE TRIGGER trg_user_investments_updated_at
BEFORE UPDATE ON public.user_investments
FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- 5. Verification query to confirm column addition
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_investments' 
  AND column_name = 'updated_at';
