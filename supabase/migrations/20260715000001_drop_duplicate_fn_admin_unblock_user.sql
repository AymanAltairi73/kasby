-- Drop the old 1-parameter version of fn_admin_unblock_user to resolve function overloading ambiguity.
-- The new 2-parameter version (with p_admin_id DEFAULT NULL) is backward compatible.

DROP FUNCTION IF EXISTS public.fn_admin_unblock_user(UUID);
