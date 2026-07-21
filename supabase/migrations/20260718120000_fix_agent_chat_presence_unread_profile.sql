-- ============================================================================
-- AGENT CHAT PRESENCE, UNREAD COUNTERS & PROFILE FIX
-- ============================================================================
-- This migration fixes:
-- 1. Agent chat unread counters in database trigger
-- 2. Agent profile display in admin conversations
-- 3. Agent presence tracking
-- ============================================================================

-- 1. Fix fn_increment_unread_counter to handle agent chat category
CREATE OR REPLACE FUNCTION public.fn_increment_unread_counter()
RETURNS TRIGGER AS $$
DECLARE
    v_category TEXT;
    v_low_id UUID;
    v_high_id UUID;
    v_is_agent_chat BOOLEAN;
    v_agent_id UUID;
BEGIN
    -- Fetch conversation details
    SELECT category, user_low_id, user_high_id, is_agent_chat, agent_id
    INTO v_category, v_low_id, v_high_id, v_is_agent_chat, v_agent_id
    FROM public.chat_conversations WHERE id = NEW.conversation_id;

    IF NOT FOUND THEN
        RETURN NEW;
    END IF;

    -- Update last message preview and time atomically
    UPDATE public.chat_conversations
    SET last_message = CASE WHEN NEW.message_type = 'image' THEN '📷 صورة' ELSE NEW.message_content END,
        last_message_at = NEW.created_at
    WHERE id = NEW.conversation_id;

    -- Increment unread counts atomically
    IF v_category = 'social' THEN
        -- P2P: increment the OTHER participant's unread counter
        IF NEW.sender_id = v_low_id THEN
            UPDATE public.chat_conversations
            SET unread_admin_count = COALESCE(unread_admin_count, 0) + 1  -- unread count for user_high_id
            WHERE id = NEW.conversation_id;
        ELSIF NEW.sender_id = v_high_id THEN
            UPDATE public.chat_conversations
            SET unread_user_count = COALESCE(unread_user_count, 0) + 1    -- unread count for user_low_id
            WHERE id = NEW.conversation_id;
        END IF;
    ELSIF COALESCE(v_is_agent_chat, false) THEN
        -- Agent chat: user ↔ agent
        IF NEW.sender_type = 'user' THEN
            -- User sends → Agent unread count (stored in unread_admin_count for agent)
            UPDATE public.chat_conversations
            SET unread_admin_count = COALESCE(unread_admin_count, 0) + 1
            WHERE id = NEW.conversation_id;
        ELSIF NEW.sender_type = 'agent' THEN
            -- Agent sends → User unread count (stored in unread_user_count for user)
            UPDATE public.chat_conversations
            SET unread_user_count = COALESCE(unread_user_count, 0) + 1
            WHERE id = NEW.conversation_id;
        END IF;
    ELSE
        -- Support chat: user/agent ↔ admin
        IF NEW.sender_type IN ('user', 'agent') THEN
            -- User/Agent sends message → Admin unread count increments
            UPDATE public.chat_conversations
            SET unread_admin_count = COALESCE(unread_admin_count, 0) + 1
            WHERE id = NEW.conversation_id;
        ELSIF NEW.sender_type = 'admin' THEN
            -- Admin sends message → User unread count increments
            UPDATE public.chat_conversations
            SET unread_user_count = COALESCE(unread_user_count, 0) + 1
            WHERE id = NEW.conversation_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix fn_sync_message_read_status to handle agent chat category
CREATE OR REPLACE FUNCTION public.fn_sync_message_read_status()
RETURNS TRIGGER AS $$
DECLARE
    v_category TEXT;
    v_is_agent_chat BOOLEAN;
BEGIN
    SELECT category, is_agent_chat INTO v_category, v_is_agent_chat
    FROM public.chat_conversations WHERE id = NEW.id;

    IF NOT FOUND THEN RETURN NEW; END IF;

    -- If unread_admin_count was set to 0, mark peer or user/agent messages as read
    IF NEW.unread_admin_count = 0 AND OLD.unread_admin_count > 0 THEN
        IF v_category = 'social' THEN
            -- High user marked read: mark low user's messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_id = NEW.user_low_id
              AND read_at IS NULL;
        ELSIF COALESCE(v_is_agent_chat, false) THEN
            -- Agent marked read: mark user's messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_type = 'user'
              AND read_at IS NULL;
        ELSE
            -- Admin marked read: mark user/agent messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_type IN ('user', 'agent')
              AND read_at IS NULL;
        END IF;
    END IF;

    -- If unread_user_count was set to 0, mark peer or admin messages as read
    IF NEW.unread_user_count = 0 AND OLD.unread_user_count > 0 THEN
        IF v_category = 'social' THEN
            -- Low user marked read: mark high user's messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_id = NEW.user_high_id
              AND read_at IS NULL;
        ELSIF COALESCE(v_is_agent_chat, false) THEN
            -- User marked read: mark agent's messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_type = 'agent'
              AND read_at IS NULL;
        ELSE
            -- User marked read: mark admin messages as read
            UPDATE public.chat_messages
            SET read_at = COALESCE(read_at, NOW())
            WHERE conversation_id = NEW.id
              AND sender_type = 'admin'
              AND read_at IS NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create view for admin to get agent conversations with correct profile data
CREATE OR REPLACE VIEW public.admin_agent_conversations_view AS
SELECT 
    c.*,
    p.full_name,
    p.avatar_url,
    p.last_seen_at,
    p.updated_at,
    p.role,
    a.user_id as agent_user_id
FROM public.chat_conversations c
LEFT JOIN public.profiles p ON c.user_id = p.id
LEFT JOIN public.agents a ON c.agent_id = a.id
WHERE c.is_agent_chat = true;

-- Grant permissions
GRANT SELECT ON public.admin_agent_conversations_view TO authenticated, service_role;

-- 4. Add helper function to get agent profile for conversations
CREATE OR REPLACE FUNCTION public.get_conversation_profile(p_conversation_id UUID)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    avatar_url TEXT,
    last_seen_at TIMESTAMPTZ,
    role TEXT,
    is_agent BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
    v_conv RECORD;
BEGIN
    SELECT * INTO v_conv
    FROM public.chat_conversations
    WHERE id = p_conversation_id;

    IF NOT FOUND THEN RETURN; END IF;

    IF v_conv.is_agent_chat THEN
        -- For agent chats, return the user's profile
        RETURN QUERY
        SELECT 
            p.id,
            p.full_name,
            p.avatar_url,
            p.last_seen_at,
            p.role::text,
            false
        FROM public.profiles p
        WHERE p.id = v_conv.user_id;
    ELSE
        -- For support/social chats, return the user's profile
        RETURN QUERY
        SELECT 
            p.id,
            p.full_name,
            p.avatar_url,
            p.last_seen_at,
            p.role::text,
            false
        FROM public.profiles p
        WHERE p.id = v_conv.user_id;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_conversation_profile TO authenticated, service_role;
