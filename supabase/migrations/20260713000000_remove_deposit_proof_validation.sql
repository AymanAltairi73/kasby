-- ============================================================================
-- REMOVE DEPOSIT PROOF VALIDATION
-- ============================================================================
-- This migration removes the mandatory payment proof requirement from deposit
-- workflows. Payment proof feature has been removed from the user app, so
-- deposits should be processed without requiring proof_url.
--
-- Changes:
-- 1. Remove proof_url validation from fn_create_deposit_request
-- 2. Remove proof_url validation from agent_approve_deposit
-- 3. Update audit logging to not assume proof is present
-- ============================================================================

-- ── 1. Remove proof validation from fn_create_deposit_request ──
DROP FUNCTION IF EXISTS public.fn_create_deposit_request(NUMERIC, UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.fn_create_deposit_request(
  p_amount NUMERIC,
  p_agent_id UUID,
  p_idempotency_key TEXT DEFAULT NULL,
  p_proof_url TEXT DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id        UUID := auth.uid();
  v_wallet         RECORD;
  v_transaction_id UUID;
  v_agent_user_id  UUID;
  v_agent_name     TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  IF p_amount < 10 THEN
    RETURN json_build_object('success', false, 'error', 'Minimum deposit is $10');
  END IF;

  -- REMOVED: Proof URL validation - no longer required
  -- IF p_proof_url IS NULL OR TRIM(p_proof_url) = '' THEN
  --   RETURN json_build_object('success', false, 'error', 'Deposit proof image is required');
  -- END IF;

  PERFORM public.fn_check_financial_permission(v_user_id, 'deposit');

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_transaction_id
      FROM transactions WHERE idempotency_key = p_idempotency_key AND user_id = v_user_id LIMIT 1;
    IF v_transaction_id IS NOT NULL THEN
      RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
    END IF;
  END IF;

  SELECT * INTO v_wallet FROM wallets WHERE user_id = v_user_id AND currency = 'USD' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Wallet not found');
  END IF;
  IF v_wallet.is_frozen THEN
    RETURN json_build_object('success', false, 'error', 'Wallet is frozen');
  END IF;

  SELECT a.user_id, COALESCE(p.full_name, 'Agent')
    INTO v_agent_user_id, v_agent_name
    FROM agents a
    LEFT JOIN profiles p ON p.id = a.user_id
    WHERE a.id = p_agent_id AND a.status = 'active';

  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Agent not found or inactive');
  END IF;

  INSERT INTO transactions (
    user_id, wallet_id, type, amount, fee, currency,
    status, reference_id, description, idempotency_key, proof_url
  ) VALUES (
    v_user_id, v_wallet.id, 'deposit', p_amount, 0, 'USD',
    'pending', p_agent_id::TEXT,
    'إيداع عبر وكيل: ' || v_agent_name,
    p_idempotency_key, NULL  -- Always NULL since proof is no longer required
  ) RETURNING id INTO v_transaction_id;

  UPDATE wallets SET
    pending_balance = pending_balance + p_amount,
    updated_at = NOW()
  WHERE id = v_wallet.id;

  PERFORM public.fn_log_financial_audit(
    v_user_id, 'user', 'deposit_submitted', v_transaction_id,
    NULL, 'pending', p_amount,
    jsonb_build_object('agent_id', p_agent_id, 'has_proof', false)
  );

  RETURN json_build_object('success', true, 'transaction_id', v_transaction_id);
END;
$$;

-- ── 2. Remove proof validation from agent_approve_deposit ──
DROP FUNCTION IF EXISTS public.agent_approve_deposit(UUID);

CREATE OR REPLACE FUNCTION public.agent_approve_deposit(p_transaction_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_user_id UUID := auth.uid();
  v_agent_id      UUID;
  v_tx            RECORD;
  v_new_bal       NUMERIC;
  v_commission    JSON;
BEGIN
  IF v_agent_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  SELECT a.id INTO v_agent_id
    FROM agents a
    WHERE a.user_id = v_agent_user_id AND a.status = 'active';

  IF v_agent_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Agent not found or inactive');
  END IF;

  SELECT * INTO v_tx
    FROM transactions
    WHERE id = p_transaction_id
      AND type = 'deposit'
      AND status = 'pending'
      AND reference_id::UUID = v_agent_id
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  -- REMOVED: Proof URL validation - no longer required
  -- IF v_tx.proof_url IS NULL OR TRIM(v_tx.proof_url) = '' THEN
  --   RETURN json_build_object('success', false, 'message', 'Deposit proof is required before approval');
  -- END IF;

  PERFORM id FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Wallet not found');
  END IF;

  -- Calculate commission
  v_commission := public.fn_process_agent_commission(v_agent_id);

  -- Update transaction status
  UPDATE transactions SET
    status = 'completed',
    processed_at = NOW(),
    running_balance = (
      SELECT available_balance FROM wallets WHERE id = v_tx.wallet_id
    ) + v_tx.amount
    WHERE id = p_transaction_id;

  -- Update wallet balance
  UPDATE wallets SET
    available_balance = available_balance + v_tx.amount,
    pending_balance = pending_balance - v_tx.amount,
    updated_at = NOW()
    WHERE id = v_tx.wallet_id;

  -- Log audit
  PERFORM public.fn_log_financial_audit(
    v_tx.user_id, 'agent', 'deposit_approved', p_transaction_id,
    'pending', 'completed', v_tx.amount,
    jsonb_build_object(
      'agent_id', v_agent_id,
      'commission', v_commission,
      'has_proof', false
    )
  );

  RETURN json_build_object(
    'success', true,
    'transaction_id', p_transaction_id,
    'commission', v_commission
  );
END;
$$;

-- ── 3. Update fn_process_deposit (admin approval) to not require proof ──
-- Drop all possible overloads of fn_process_deposit explicitly
DROP FUNCTION IF EXISTS public.fn_process_deposit(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.fn_process_deposit(UUID) CASCADE;
DROP FUNCTION IF EXISTS public.fn_process_deposit(TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.fn_process_deposit(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.fn_process_deposit(UUID, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.fn_process_deposit(TEXT, UUID, TEXT) CASCADE;

CREATE OR REPLACE FUNCTION public.fn_process_deposit(
  p_txn_id UUID,
  p_admin_id UUID DEFAULT NULL
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_admin_user_id UUID := COALESCE(p_admin_id, auth.uid());
  v_tx RECORD;
  v_wallet RECORD;
  v_agent_id UUID;
BEGIN
  IF v_admin_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  -- Check admin permission
  IF NOT EXISTS (
    SELECT 1 FROM admin_users 
    WHERE user_id = v_admin_user_id AND status = 'active'
  ) THEN
    RETURN json_build_object('success', false, 'error', 'Admin access required');
  END IF;

  SELECT * INTO v_tx
    FROM transactions
    WHERE id = p_txn_id AND type = 'deposit'
    FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Transaction not found');
  END IF;

  IF v_tx.status != 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'Transaction already processed');
  END IF;

  -- REMOVED: Proof URL validation - no longer required
  -- IF v_tx.proof_url IS NULL OR TRIM(v_tx.proof_url) = '' THEN
  --   RETURN json_build_object('success', false, 'error', 'Deposit proof is required');
  -- END IF;

  SELECT * INTO v_wallet FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Wallet not found');
  END IF;

  -- Get agent ID from reference_id
  v_agent_id := v_tx.reference_id::UUID;

  -- Update transaction
  UPDATE transactions SET
    status = 'completed',
    processed_at = NOW(),
    running_balance = v_wallet.available_balance + v_tx.amount
    WHERE id = p_txn_id;

  -- Update wallet
  UPDATE wallets SET
    available_balance = available_balance + v_tx.amount,
    pending_balance = pending_balance - v_tx.amount,
    updated_at = NOW()
    WHERE id = v_wallet.id;

  -- Process agent commission if applicable
  IF v_agent_id IS NOT NULL THEN
    PERFORM public.fn_process_agent_commission(v_agent_id);
  END IF;

  -- Log audit
  PERFORM public.fn_log_financial_audit(
    v_tx.user_id, 'admin', 'deposit_approved', p_txn_id,
    'pending', 'completed', v_tx.amount,
    jsonb_build_object('admin_id', v_admin_user_id, 'agent_id', v_agent_id, 'has_proof', false)
  );

  RETURN json_build_object('success', true, 'transaction_id', p_txn_id);
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.fn_create_deposit_request TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_approve_deposit TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_process_deposit TO authenticated;
