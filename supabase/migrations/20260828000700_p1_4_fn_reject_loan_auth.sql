-- =============================================================================
-- P1-4: fn_reject_loan authorization (CONFIRMED-LIVE broken access control)
--
-- Scope (user-approved, strictly minimal):
--   - Signature preserved EXACTLY: public.fn_reject_loan(uuid, uuid, text)
--   - Return type (void) and loan-rejection logic preserved unchanged.
--   - Require auth.uid() IS NOT NULL.
--   - Require public.is_admin() = true BEFORE any loan mutation.
--   - Effective admin identity forced to auth.uid(); caller-supplied
--     p_admin_id is ignored completely (no attribution forgery).
--   - Preserve FOR UPDATE, pending-status check, rejection fields,
--     timestamps, and audit_logs insert behavior verbatim.
--   - Least privilege: REVOKE EXECUTE from PUBLIC and anon; GRANT EXECUTE
--     to authenticated (body guarded by is_admin()).
--
-- NOT changed (explicitly out of scope): fn_approve_loan, loans schema,
-- audit_logs schema, wallets, and any other function/table. No SET
-- search_path TO public and no other unrelated hardening.
--
-- Rollback: re-apply the captured live baseline body (see before-capture)
-- with REVOKE ... FROM PUBLIC, anon restored and anon/PUBLIC EXECUTE back.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.fn_reject_loan(p_loan_id uuid, p_admin_id uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_user_id UUID;
    v_amount NUMERIC(18,4);
    v_status loan_status;
    v_admin_id UUID;
BEGIN
    -- P1-4 authorization: require an authenticated admin session.
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'UNAUTHORIZED';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Admin access required';
    END IF;

    -- Caller-supplied p_admin_id is ignored; effective admin is auth.uid().

    -- Get loan details
    SELECT user_id, amount, status INTO v_user_id, v_amount, v_status
    FROM loans WHERE id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan not found.';
    END IF;

    IF v_status != 'pending' THEN
        RAISE EXCEPTION 'Loan is not in pending status.';
    END IF;

    -- Update loan status to rejected
    UPDATE loans
    SET
      status = 'rejected',
      rejected_by = v_admin_id,
      rejected_at = CURRENT_TIMESTAMP,
      rejection_reason = p_reason,
      updated_at = NOW()
    WHERE id = p_loan_id;

    -- Insert into audit_logs with details as jsonb
    INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
    VALUES (
      v_admin_id,
      'reject_loan',
      jsonb_build_object(
        'reason', p_reason,
        'amount', v_amount,
        'user_id', v_user_id
      ),
      'financial',
      'success',
      p_loan_id::TEXT,
      'loan'
    );
END;
$function$;

-- Least privilege (P1-4)
REVOKE ALL ON FUNCTION public.fn_reject_loan(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_reject_loan(uuid, uuid, text) TO authenticated;
