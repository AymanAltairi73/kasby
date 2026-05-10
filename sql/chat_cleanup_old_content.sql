-- ==============================================================================
-- KASBY CHAT CLEANUP — Drop Old content Column
-- Date: 2026-04-XX (Run AFTER all Flutter apps are deployed and using message_content)
--
-- ⚠️  DO NOT RUN THIS UNTIL:
--   ✅ chat_content_rename_migration.sql has been deployed
--   ✅ Both Flutter apps (User + Admin) have been updated to use message_content
--   ✅ All clients in the wild are using the new column
--   ✅ Verified no direct queries reference 'content' anymore
--
-- WHAT THIS DOES:
--   1. Pre-checks that message_content column exists (abort if not)
--   2. Drops the sync trigger (no longer needed)
--   3. Makes message_content NOT NULL
--   4. Drops the old content column
--
-- INSTRUCTIONS:
--   1. BACKUP YOUR DATABASE FIRST
--   2. Run in Supabase SQL Editor
--   3. Verify: SELECT * FROM chat_messages LIMIT 5;
-- ==============================================================================

BEGIN;

-- ═══════════════════════════════════════════════
-- SAFETY PRE-CHECK: Abort if migration hasn't been applied
-- ═══════════════════════════════════════════════
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'chat_messages' 
          AND column_name = 'message_content'
    ) THEN
        RAISE EXCEPTION 
            'ABORT: message_content column does not exist. '
            'You must run chat_content_rename_migration.sql FIRST before running this cleanup.';
    END IF;

    -- Also verify no NULL message_content values remain
    IF EXISTS (
        SELECT 1 FROM public.chat_messages 
        WHERE message_content IS NULL AND content IS NOT NULL
        LIMIT 1
    ) THEN
        RAISE EXCEPTION 
            'ABORT: Found rows where message_content is NULL but content is not. '
            'The sync trigger may not have backfilled all data. Fix this before cleanup.';
    END IF;

    RAISE NOTICE 'Pre-checks passed. Proceeding with cleanup...';
END $$;

-- 1. Drop sync trigger (both columns no longer needed)
DROP TRIGGER IF EXISTS trg_sync_chat_content ON public.chat_messages;
DROP FUNCTION IF EXISTS public.fn_sync_chat_message_content();

-- 2. Make message_content NOT NULL (since all data should be there now)
ALTER TABLE public.chat_messages
    ALTER COLUMN message_content SET NOT NULL;

-- 3. Drop old content column
ALTER TABLE public.chat_messages
    DROP COLUMN IF EXISTS content;

-- 4. Update comment
COMMENT ON COLUMN public.chat_messages.message_content IS 'The actual message body text';

COMMIT;

-- ==============================================================================
-- END OF CLEANUP
-- ==============================================================================
