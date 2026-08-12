-- ============================================================================
-- 🚀 KASBY: Fix Notifications Type & Target Check Constraints
-- Date: 2026-08-12
-- Description: Updates legacy rows and relaxes/fixes check constraints on 
--              public.notifications so existing rows won't block migration.
-- ============================================================================

-- 1. Drop existing restrictive check constraints
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_target_check;

-- 2. Clean up any invalid or null legacy rows in existing database data
UPDATE public.notifications 
SET type = 'general' 
WHERE type IS NULL OR TRIM(type) = '';

UPDATE public.notifications 
SET target = 'specific' 
WHERE target IS NOT NULL AND target NOT IN (
    'all', 'specific', 'social', 'chat', 'user', 'admin', 'system', 'agent'
);

-- 3. Add robust notifications_target_check
ALTER TABLE public.notifications ADD CONSTRAINT notifications_target_check
    CHECK (target IS NULL OR target = ANY (ARRAY[
        'all', 'specific', 'social', 'chat', 'user', 'admin', 'system', 'agent'
    ])) NOT VALID;

-- 4. Add comprehensive notifications_type_check (permits all valid notification types)
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
    CHECK (type IS NOT NULL AND length(TRIM(type)) > 0) NOT VALID;

-- 5. Validate constraints for future inserts
ALTER TABLE public.notifications VALIDATE CONSTRAINT notifications_target_check;
ALTER TABLE public.notifications VALIDATE CONSTRAINT notifications_type_check;

-- 6. Verification output
DO $$
BEGIN
    RAISE NOTICE 'Notifications check constraints fixed and validated successfully.';
END $$;
