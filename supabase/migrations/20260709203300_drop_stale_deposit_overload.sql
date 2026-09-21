-- Drop the stale 3-parameter overload of fn_create_deposit_request.
-- PostgREST (PGRST203) cannot disambiguate between
--   fn_create_deposit_request(NUMERIC, UUID, TEXT)          -- old 3-arg
--   fn_create_deposit_request(NUMERIC, UUID, TEXT, TEXT)    -- current 4-arg
-- when the client omits p_proof_url (which has DEFAULT NULL).
-- Only the 4-arg version (from 20260629230000) should remain.

DROP FUNCTION IF EXISTS public.fn_create_deposit_request(NUMERIC, UUID, TEXT);
