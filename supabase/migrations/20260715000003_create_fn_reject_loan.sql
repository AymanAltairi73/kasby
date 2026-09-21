-- Add missing columns to loans table for rejection tracking
ALTER TABLE public.loans
ADD COLUMN IF NOT EXISTS rejected_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Create fn_reject_loan function to handle loan rejection
-- This function properly handles the details column as jsonb

CREATE OR REPLACE FUNCTION public.fn_reject_loan(
  p_loan_id uuid,
  p_admin_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_amount NUMERIC(18,4);
    v_status loan_status;
BEGIN
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
      rejected_by = p_admin_id,
      rejected_at = CURRENT_TIMESTAMP,
      rejection_reason = p_reason,
      updated_at = NOW()
    WHERE id = p_loan_id;

    -- Insert into audit_logs with details as jsonb
    INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
    VALUES (
      p_admin_id,
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
$$;
