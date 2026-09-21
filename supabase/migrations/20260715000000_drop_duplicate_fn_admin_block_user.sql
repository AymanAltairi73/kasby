-- Drop the old 2-parameter version of fn_admin_block_user to resolve function overloading ambiguity.
-- The new 3-parameter version (with p_admin_id DEFAULT NULL) is backward compatible.

DROP FUNCTION IF EXISTS public.fn_admin_block_user(UUID, TEXT);
