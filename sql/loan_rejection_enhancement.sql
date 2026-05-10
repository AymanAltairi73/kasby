-- ============================================================================
-- Kasby Enhancement: Loan Rejection Reasons
-- Adds support for giving feedback to users when a loan is rejected.
-- ============================================================================

-- 1. Add rejection_reason column to loans table
ALTER TABLE loans ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2. Create a function to reject a loan with a reason
-- This replaces the direct update in the admin app for better consistency
CREATE OR REPLACE FUNCTION reject_loan(p_loan_id UUID, p_reason TEXT)
RETURNS JSONB AS $$
DECLARE
    v_loan_status TEXT;
BEGIN
    SELECT status INTO v_loan_status FROM loans WHERE id = p_loan_id;
    
    IF v_loan_status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Only pending loans can be rejected');
    END IF;

    UPDATE loans 
    SET status = 'rejected', 
        rejection_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_loan_id;

    RETURN jsonb_build_object('success', true, 'message', 'Loan rejected with reason');
END;
$$ LANGUAGE plpgsql;
