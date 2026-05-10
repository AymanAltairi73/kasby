-- ============================================================
-- 🛠️ FIX SPIN HISTORY SCHEMA
-- ============================================================

BEGIN;

-- 1. Add spin_type if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'spin_history' AND column_name = 'spin_type') THEN
        ALTER TABLE public.spin_history ADD COLUMN spin_type TEXT;
    END IF;
END $$;

-- 2. Migrate data from is_free if it exists
DO $$ 
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'spin_history' AND column_name = 'is_free') THEN
        UPDATE public.spin_history 
        SET spin_type = CASE WHEN is_free THEN 'free' ELSE 'paid' END
        WHERE spin_type IS NULL;
        
        ALTER TABLE public.spin_history DROP COLUMN is_free;
    END IF;
END $$;

-- 3. Set default and NOT NULL for spin_type
UPDATE public.spin_history SET spin_type = 'paid' WHERE spin_type IS NULL;
ALTER TABLE public.spin_history ALTER COLUMN spin_type SET NOT NULL;
ALTER TABLE public.spin_history ALTER COLUMN spin_type SET DEFAULT 'paid';

COMMIT;
