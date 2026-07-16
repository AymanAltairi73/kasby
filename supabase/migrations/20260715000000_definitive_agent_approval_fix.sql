-- ============================================================================
-- DEFINITIVE AGENT APPROVAL FIX
-- ============================================================================
-- Root causes fixed:
--   A) TEXT vs UUID type mismatch: reference_id (TEXT) compared to v_agent_id (UUID)
--      Fix: Explicit cast → reference_id = v_agent_id::TEXT
--   B) Transactions stuck in 'processing' from failed two-phase withdrawal updates
--      Fix: Reset stuck rows + accept status IN ('pending','processing')
--   C) Migration 20260714 removed reference_id security check
--      Fix: Restore proper agent-owns-transaction authorization
-- ============================================================================

-- ── 0. DATA REPAIR: Reset stuck 'processing' transactions ──
UPDATE transactions
SET status = 'pending'
WHERE status = 'processing'
  AND type IN ('deposit', 'withdrawal');

-- ── 1. DEFINITIVE agent_approve_deposit ──
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
  v_wallet        RECORD;
  v_agent_name    TEXT;
  v_user_name     TEXT;
  v_ref_short     TEXT;
  v_amount_text   TEXT;
  v_admin_ids     UUID[];
  v_admin_user_id UUID;
  v_commission    JSON;
  v_debug_ref     TEXT;
  v_debug_status  TEXT;
  v_debug_type    TEXT;
BEGIN
  -- ── Step 1: Auth check ──
  RAISE LOG '[DEPOSIT_APPROVE] ▶ Start. tx=%, auth.uid=%', p_transaction_id, v_agent_user_id;

  IF v_agent_user_id IS NULL THEN
    RAISE LOG '[DEPOSIT_APPROVE] ✗ Unauthorized (auth.uid is NULL)';
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  -- ── Step 2: Resolve agent ──
  SELECT a.id INTO v_agent_id
    FROM agents a
    WHERE a.user_id = v_agent_user_id AND a.status = 'active';

  RAISE LOG '[DEPOSIT_APPROVE] ℹ agent_id=% (from user_id=%)', v_agent_id, v_agent_user_id;

  IF v_agent_id IS NULL THEN
    RAISE LOG '[DEPOSIT_APPROVE] ✗ Agent not found or inactive for user_id=%', v_agent_user_id;
    RETURN json_build_object('success', false, 'message', 'Agent not found or inactive');
  END IF;

  -- ── Step 3: Get agent name ──
  SELECT COALESCE(p.full_name, 'Agent') INTO v_agent_name
    FROM profiles p WHERE p.id = v_agent_user_id;

  -- ── Step 4: Find & lock transaction (EXPLICIT TEXT CAST) ──
  RAISE LOG '[DEPOSIT_APPROVE] ℹ Looking for tx: id=%, type=deposit, status IN (pending,processing), reference_id=% (agent_id::TEXT)',
    p_transaction_id, v_agent_id::TEXT;

  SELECT * INTO v_tx
    FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT   -- ← EXPLICIT CAST (Root Cause A fix)
      AND type = 'deposit'
      AND status IN ('pending', 'processing')  -- ← Both statuses (Root Cause B fix)
    FOR UPDATE;

  IF NOT FOUND THEN
    -- Debug: why did it fail?
    SELECT reference_id, status, type
      INTO v_debug_ref, v_debug_status, v_debug_type
      FROM transactions WHERE id = p_transaction_id;

    IF v_debug_ref IS NULL AND v_debug_status IS NULL THEN
      RAISE LOG '[DEPOSIT_APPROVE] ✗ Transaction % does not exist at all', p_transaction_id;
    ELSE
      RAISE LOG '[DEPOSIT_APPROVE] ✗ Transaction exists but no match. ref=% (expected=%), status=% (expected pending/processing), type=% (expected deposit)',
        v_debug_ref, v_agent_id::TEXT, v_debug_status, v_debug_type;
    END IF;

    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  RAISE LOG '[DEPOSIT_APPROVE] ✓ Transaction found. id=%, user_id=%, amount=%, status=%',
    v_tx.id, v_tx.user_id, v_tx.amount, v_tx.status;

  -- ── Step 5: Lock wallet ──
  SELECT * INTO v_wallet FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE LOG '[DEPOSIT_APPROVE] ✗ Wallet not found for wallet_id=%', v_tx.wallet_id;
    RETURN json_build_object('success', false, 'message', 'Wallet not found');
  END IF;

  -- ── Step 6: Get user name ──
  SELECT COALESCE(full_name, 'User') INTO v_user_name
    FROM profiles WHERE id = v_tx.user_id;

  -- ── Step 7: Process commission ──
  BEGIN
    v_commission := public.fn_process_agent_commission(v_agent_id);
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[DEPOSIT_APPROVE] ⚠ Commission processing failed: %', SQLERRM;
    v_commission := json_build_object('warning', 'Commission processing failed: ' || SQLERRM);
  END;

  -- ── Step 8: Update transaction ──
  UPDATE transactions SET
    status = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW(),
    running_balance = v_wallet.available_balance + v_tx.amount
    WHERE id = p_transaction_id;

  -- ── Step 9: Update wallet ──
  UPDATE wallets SET
    available_balance = available_balance + v_tx.amount,
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
    updated_at = NOW()
    WHERE id = v_tx.wallet_id;

  -- ── Step 10: Update agent stats ──
  UPDATE agents SET
    total_transactions = total_transactions + 1,
    last_active_at = NOW()
    WHERE id = v_agent_id;

  -- ── Step 11: Notifications ──
  v_ref_short := UPPER(SUBSTRING(p_transaction_id::TEXT FROM 1 FOR 8));
  v_amount_text := TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM v_tx.amount::TEXT));

  -- Notify user
  BEGIN
    PERFORM fn_create_notification(
      v_tx.user_id,
      'deposit_approved_title',
      'deposit_approved_message',
      'deposit_approved',
      'transaction',
      p_transaction_id::TEXT,
      '/wallet',
      'user',
      'high',
      jsonb_build_object(
        'amount', v_amount_text,
        'agent_name', v_agent_name,
        'ref', v_ref_short
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[DEPOSIT_APPROVE] ⚠ User notification failed: %', SQLERRM;
  END;

  -- Notify admins
  BEGIN
    SELECT ARRAY_AGG(id) INTO v_admin_ids
      FROM profiles WHERE role = 'admin';

    IF v_admin_ids IS NOT NULL AND array_length(v_admin_ids, 1) > 0 THEN
      FOREACH v_admin_user_id IN ARRAY v_admin_ids LOOP
        PERFORM fn_create_notification(
          v_admin_user_id,
          'admin_deposit_approved_title',
          'admin_deposit_approved_message',
          'admin_deposit_approved',
          'transaction',
          p_transaction_id::TEXT,
          '/admin/deposits',
          'admin',
          'normal',
          jsonb_build_object(
            'user_name', v_user_name,
            'agent_name', v_agent_name,
            'amount', v_amount_text,
            'ref', v_ref_short
          )
        );
      END LOOP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[DEPOSIT_APPROVE] ⚠ Admin notification failed: %', SQLERRM;
  END;

  -- ── Step 12: Audit ──
  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_tx.user_id, 'agent', 'deposit_approved', p_transaction_id,
      'pending', 'completed', v_tx.amount,
      jsonb_build_object(
        'agent_id', v_agent_id,
        'commission', v_commission,
        'admin_notified', v_admin_ids IS NOT NULL
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[DEPOSIT_APPROVE] ⚠ Audit log failed: %', SQLERRM;
  END;

  RAISE LOG '[DEPOSIT_APPROVE] ✓ SUCCESS. tx=%, agent=%, user=%', p_transaction_id, v_agent_id, v_tx.user_id;

  RETURN json_build_object(
    'success', true,
    'transaction_id', p_transaction_id,
    'commission', v_commission
  );
END;
$$;


-- ── 2. DEFINITIVE agent_confirm_withdrawal ──
DROP FUNCTION IF EXISTS public.agent_confirm_withdrawal(UUID);

CREATE OR REPLACE FUNCTION public.agent_confirm_withdrawal(p_transaction_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_user_id UUID := auth.uid();
  v_agent_id      UUID;
  v_tx            RECORD;
  v_wallet        RECORD;
  v_agent_name    TEXT;
  v_user_name     TEXT;
  v_debug_ref     TEXT;
  v_debug_status  TEXT;
  v_debug_type    TEXT;
BEGIN
  -- ── Step 1: Auth check ──
  RAISE LOG '[WITHDRAWAL_CONFIRM] ▶ Start. tx=%, auth.uid=%', p_transaction_id, v_agent_user_id;

  IF v_agent_user_id IS NULL THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] ✗ Unauthorized (auth.uid is NULL)';
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  -- ── Step 2: Resolve agent ──
  SELECT a.id INTO v_agent_id
    FROM agents a
    WHERE a.user_id = v_agent_user_id AND a.status = 'active';

  RAISE LOG '[WITHDRAWAL_CONFIRM] ℹ agent_id=% (from user_id=%)', v_agent_id, v_agent_user_id;

  IF v_agent_id IS NULL THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] ✗ Agent not found or inactive for user_id=%', v_agent_user_id;
    RETURN json_build_object('success', false, 'message', 'Agent not found or inactive');
  END IF;

  -- ── Step 3: Get agent name ──
  SELECT COALESCE(p.full_name, 'Agent') INTO v_agent_name
    FROM profiles p WHERE p.id = v_agent_user_id;

  -- ── Step 4: Find & lock transaction (EXPLICIT TEXT CAST) ──
  RAISE LOG '[WITHDRAWAL_CONFIRM] ℹ Looking for tx: id=%, type=withdrawal, status IN (pending,processing), reference_id=% (agent_id::TEXT)',
    p_transaction_id, v_agent_id::TEXT;

  SELECT * INTO v_tx
    FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT   -- ← EXPLICIT CAST
      AND type = 'withdrawal'
      AND status IN ('pending', 'processing')
    FOR UPDATE;

  IF NOT FOUND THEN
    -- Debug: why did it fail?
    SELECT reference_id, status, type
      INTO v_debug_ref, v_debug_status, v_debug_type
      FROM transactions WHERE id = p_transaction_id;

    IF v_debug_ref IS NULL AND v_debug_status IS NULL THEN
      RAISE LOG '[WITHDRAWAL_CONFIRM] ✗ Transaction % does not exist at all', p_transaction_id;
    ELSE
      RAISE LOG '[WITHDRAWAL_CONFIRM] ✗ Transaction exists but no match. ref=% (expected=%), status=% (expected pending/processing), type=% (expected withdrawal)',
        v_debug_ref, v_agent_id::TEXT, v_debug_status, v_debug_type;
    END IF;

    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  RAISE LOG '[WITHDRAWAL_CONFIRM] ✓ Transaction found. id=%, user_id=%, amount=%, status=%',
    v_tx.id, v_tx.user_id, v_tx.amount, v_tx.status;

  -- ── Step 5: Lock wallet ──
  SELECT * INTO v_wallet FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] ✗ Wallet not found for wallet_id=%', v_tx.wallet_id;
    RETURN json_build_object('success', false, 'message', 'Wallet not found');
  END IF;

  -- ── Step 6: Get user name ──
  SELECT COALESCE(full_name, 'User') INTO v_user_name
    FROM profiles WHERE id = v_tx.user_id;

  -- ── Step 7: Update transaction (SINGLE atomic update, no two-phase) ──
  UPDATE transactions SET
    status = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW()
    WHERE id = p_transaction_id;

  -- ── Step 8: Update wallet ──
  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
    updated_at = NOW()
    WHERE id = v_tx.wallet_id;

  -- ── Step 9: Update agent stats ──
  UPDATE agents SET
    total_transactions = total_transactions + 1,
    last_active_at = NOW()
    WHERE id = v_agent_id;

  -- ── Step 10: Notify user ──
  BEGIN
    INSERT INTO notifications (user_id, title, message, type, status, sent_at)
    VALUES (
      v_tx.user_id,
      'تم تأكيد السحب',
      'تم صرف مبلغ $' || v_tx.amount || ' USD بنجاح من قِبل الوكيل ' || v_agent_name,
      'success', 'sent', NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] ⚠ User notification failed: %', SQLERRM;
  END;

  -- ── Step 11: Audit ──
  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_tx.user_id, 'agent', 'withdrawal_confirmed', p_transaction_id,
      v_tx.status, 'completed', v_tx.amount,
      jsonb_build_object('agent_id', v_agent_id, 'agent_name', v_agent_name)
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] ⚠ Audit log failed: %', SQLERRM;
  END;

  RAISE LOG '[WITHDRAWAL_CONFIRM] ✓ SUCCESS. tx=%, agent=%, user=%', p_transaction_id, v_agent_id, v_tx.user_id;

  RETURN json_build_object('success', true);
END;
$$;


-- ── 3. DEFINITIVE agent_reject_transaction ──
DROP FUNCTION IF EXISTS public.agent_reject_transaction(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.agent_reject_transaction(
  p_transaction_id UUID,
  p_reason TEXT
) RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_agent_user_id UUID := auth.uid();
  v_agent_id      UUID;
  v_tx            RECORD;
  v_wallet        RECORD;
  v_agent_name    TEXT;
  v_user_name     TEXT;
  v_ref_short     TEXT;
  v_amount_text   TEXT;
  v_notif_type    TEXT;
  v_title_key     TEXT;
  v_message_key   TEXT;
  v_admin_ids     UUID[];
  v_admin_user_id UUID;
BEGIN
  -- ── Step 1: Auth check ──
  RAISE LOG '[REJECT_TX] ▶ Start. tx=%, auth.uid=%', p_transaction_id, v_agent_user_id;

  IF v_agent_user_id IS NULL THEN
    RAISE LOG '[REJECT_TX] ✗ Unauthorized';
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  -- ── Step 2: Resolve agent ──
  SELECT id INTO v_agent_id
    FROM agents
    WHERE user_id = v_agent_user_id AND status = 'active';

  IF v_agent_id IS NULL THEN
    RAISE LOG '[REJECT_TX] ✗ Agent not found or inactive for user_id=%', v_agent_user_id;
    RETURN json_build_object('success', false, 'message', 'Agent not found or inactive');
  END IF;

  -- ── Step 3: Get agent name ──
  SELECT COALESCE(full_name, 'Agent') INTO v_agent_name
    FROM profiles WHERE id = v_agent_user_id;

  -- ── Step 4: Find & lock transaction (EXPLICIT TEXT CAST) ──
  SELECT * INTO v_tx
    FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT   -- ← EXPLICIT CAST
      AND status IN ('pending', 'processing')
    FOR UPDATE;

  IF NOT FOUND THEN
    RAISE LOG '[REJECT_TX] ✗ Transaction not found or not authorized. tx=%, agent=%', p_transaction_id, v_agent_id;
    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  -- ── Step 5: Lock wallet ──
  SELECT * INTO v_wallet FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;

  -- ── Step 6: Get user name ──
  SELECT COALESCE(full_name, 'User') INTO v_user_name
    FROM profiles WHERE id = v_tx.user_id;

  -- ── Step 7: Update transaction ──
  UPDATE transactions SET
    status = 'rejected',
    rejection_reason = COALESCE(NULLIF(TRIM(p_reason), ''), 'رفض بواسطة الوكيل'),
    processed_by = v_agent_user_id,
    processed_at = NOW()
    WHERE id = p_transaction_id;

  -- ── Step 8: Wallet rollback based on type ──
  IF v_tx.type = 'deposit' THEN
    UPDATE wallets SET
      pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
      updated_at = NOW()
      WHERE id = v_tx.wallet_id;
  ELSIF v_tx.type = 'withdrawal' THEN
    UPDATE wallets SET
      available_balance = available_balance + v_tx.amount,
      pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
      updated_at = NOW()
      WHERE id = v_tx.wallet_id;
  END IF;

  -- ── Step 9: Notification details ──
  v_ref_short := UPPER(SUBSTRING(p_transaction_id::TEXT FROM 1 FOR 8));
  v_amount_text := TRIM(TRAILING '0' FROM TRIM(TRAILING '.' FROM v_tx.amount::TEXT));

  IF v_tx.type = 'deposit' THEN
    v_notif_type := 'deposit_rejected';
    v_title_key := 'deposit_rejected_title';
    v_message_key := 'deposit_rejected_message';
  ELSE
    v_notif_type := 'withdrawal_rejected';
    v_title_key := 'withdrawal_rejected_title';
    v_message_key := 'withdrawal_rejected_message';
  END IF;

  -- Notify user
  BEGIN
    PERFORM fn_create_notification(
      v_tx.user_id,
      v_title_key,
      v_message_key,
      v_notif_type,
      'transaction',
      p_transaction_id::TEXT,
      '/wallet',
      'user',
      'high',
      jsonb_build_object(
        'amount', v_amount_text,
        'agent_name', v_agent_name,
        'ref', v_ref_short,
        'reason', COALESCE(NULLIF(TRIM(p_reason), ''), 'رفض بواسطة الوكيل')
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[REJECT_TX] ⚠ User notification failed: %', SQLERRM;
  END;

  -- Notify admins
  BEGIN
    SELECT ARRAY_AGG(id) INTO v_admin_ids
      FROM profiles WHERE role = 'admin';

    IF v_admin_ids IS NOT NULL AND array_length(v_admin_ids, 1) > 0 THEN
      FOREACH v_admin_user_id IN ARRAY v_admin_ids LOOP
        PERFORM fn_create_notification(
          v_admin_user_id,
          'admin_tx_rejected_title',
          'admin_tx_rejected_message',
          'admin_tx_rejected',
          'transaction',
          p_transaction_id::TEXT,
          '/admin/transactions',
          'admin',
          'normal',
          jsonb_build_object(
            'user_name', v_user_name,
            'agent_name', v_agent_name,
            'amount', v_amount_text,
            'type', v_tx.type,
            'ref', v_ref_short,
            'reason', COALESCE(NULLIF(TRIM(p_reason), ''), 'رفض بواسطة الوكيل')
          )
        );
      END LOOP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[REJECT_TX] ⚠ Admin notification failed: %', SQLERRM;
  END;

  -- ── Step 10: Audit ──
  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_tx.user_id, 'agent', v_tx.type || '_rejected', p_transaction_id,
      v_tx.status, 'rejected', v_tx.amount,
      jsonb_build_object(
        'agent_id', v_agent_id,
        'reason', COALESCE(NULLIF(TRIM(p_reason), ''), 'رفض بواسطة الوكيل')
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[REJECT_TX] ⚠ Audit log failed: %', SQLERRM;
  END;

  RAISE LOG '[REJECT_TX] ✓ SUCCESS. tx=%, type=%, agent=%', p_transaction_id, v_tx.type, v_agent_id;

  RETURN json_build_object('success', true, 'message', 'Transaction rejected');
END;
$$;


-- ── 4. GRANT PERMISSIONS ──
GRANT EXECUTE ON FUNCTION public.agent_approve_deposit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_confirm_withdrawal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_reject_transaction(UUID, TEXT) TO authenticated;
