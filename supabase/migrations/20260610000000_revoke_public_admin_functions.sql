-- ============================================================================
-- CRITICAL SECURITY FIX: Revoke public access to admin balance functions
-- ============================================================================
-- This migration revokes public (anon and authenticated) access to admin-only
-- functions that allow adding/deducting user balances. These functions should
-- only be accessible via service_role key in the admin app.
-- ============================================================================

-- Revoke public access from fn_admin_add_balance
REVOKE ALL ON FUNCTION "public"."fn_admin_add_balance"("p_user_id" "uuid", "p_amount" numeric) FROM anon;
REVOKE ALL ON FUNCTION "public"."fn_admin_add_balance"("p_user_id" "uuid", "p_amount" numeric) FROM authenticated;

-- Ensure service_role still has access
GRANT ALL ON FUNCTION "public"."fn_admin_add_balance"("p_user_id" "uuid", "p_amount" numeric) TO service_role;

-- Revoke public access from fn_admin_deduct_balance
REVOKE ALL ON FUNCTION "public"."fn_admin_deduct_balance"("p_user_id" "uuid", "p_amount" numeric) FROM anon;
REVOKE ALL ON FUNCTION "public"."fn_admin_deduct_balance"("p_user_id" "uuid", "p_amount" numeric) FROM authenticated;

-- Ensure service_role still has access
GRANT ALL ON FUNCTION "public"."fn_admin_deduct_balance"("p_user_id" "uuid", "p_amount" numeric) TO service_role;
