-- =====================================================================================
-- Migration: Chat Delivery Status, Presence, and Attachments Readiness
-- Purpose: Add missing read_at column, add delivery receipts support, presence tracking, 
--          and JSONB attachment_metadata for future attachments expansion.
-- =====================================================================================

-- 1. Add read_at to chat_messages (CRITICAL — fixes broken DB functions)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Add delivered_at to chat_messages (for delivery receipts)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ DEFAULT NULL;

-- 3. Add attachment_metadata to chat_messages (for future attachments without breaking schema)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS attachment_metadata JSONB DEFAULT NULL;

-- 3b. Add reactions to chat_messages (for emoji reactions)
ALTER TABLE public.chat_messages
  ADD COLUMN IF NOT EXISTS reactions JSONB DEFAULT '[]'::jsonb;

-- 4. Add last_seen_at to profiles (for presence/last seen display)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NULL;

-- 5. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_chat_messages_read_at
  ON public.chat_messages (conversation_id, read_at)
  WHERE read_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_chat_messages_delivered_at
  ON public.chat_messages (conversation_id, delivered_at)
  WHERE delivered_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_last_seen_at
  ON public.profiles (last_seen_at DESC NULLS LAST);

-- 6. RPC: Mark messages as delivered (called by recipient client on receive)
CREATE OR REPLACE FUNCTION public.fn_mark_messages_delivered(p_conversation_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;
  
  UPDATE public.chat_messages
  SET delivered_at = COALESCE(delivered_at, NOW())
  WHERE conversation_id = p_conversation_id
    AND sender_id != v_user_id
    AND delivered_at IS NULL;
END;
$$;

-- 7. RPC: Update last_seen_at on profiles
CREATE OR REPLACE FUNCTION public.fn_update_last_seen()
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.profiles
  SET last_seen_at = NOW()
  WHERE id = auth.uid();
END;
$$;

-- Grant execute permissions to roles
GRANT EXECUTE ON FUNCTION public.fn_mark_messages_delivered(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_update_last_seen() TO authenticated, service_role;
