-- ============================================================================
-- PIN MESSAGE FEATURE
-- ============================================================================
-- This migration adds support for pinning messages in conversations
-- ============================================================================

-- 1. Add pinned_at column to chat_conversations table
ALTER TABLE public.chat_conversations 
ADD COLUMN IF NOT EXISTS pinned_message_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;

-- 2. Create function to pin a message
CREATE OR REPLACE FUNCTION public.pin_message(p_conversation_id UUID, p_message_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Verify message belongs to conversation
    IF NOT EXISTS (
        SELECT 1 FROM public.chat_messages 
        WHERE id = p_message_id AND conversation_id = p_conversation_id
    ) THEN
        RETURN FALSE;
    END IF;

    -- Update conversation with pinned message
    UPDATE public.chat_conversations
    SET pinned_message_id = p_message_id,
        pinned_at = NOW()
    WHERE id = p_conversation_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create function to unpin a message
CREATE OR REPLACE FUNCTION public.unpin_message(p_conversation_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.chat_conversations
    SET pinned_message_id = NULL,
        pinned_at = NULL
    WHERE id = p_conversation_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Grant execute permissions
GRANT EXECUTE ON FUNCTION public.pin_message TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.unpin_message TO authenticated, service_role;
