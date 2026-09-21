-- =============================================================================
-- P1-3: Agent Commission Fix (read-only-audit approved scope)
--
-- Authoritative source being corrected:
--   supabase/migrations/20260715000000_definitive_agent_approval_fix.sql
--
-- Scope (user-approved): Agent deposit + agent withdrawal commission only.
--   - agent_approve_deposit   : restore deposit commission (1.0%) by passing the
--                               correct transaction id AND running ONLY after the
--                               transaction is marked 'completed'.
--   - agent_confirm_withdrawal: add withdrawal commission (1.5%) that is run ONLY
--                               after the transaction is marked 'completed'.
--   - admin approve_withdrawal: intentionally UNCHANGED (never wired commission in
--                               any version; out of approved scope).
--
-- Financial-safety constraints honored:
--   * fn_process_agent_commission is NOT modified (contract, validation,
--     idempotency, 1.0%/1.5% rates unchanged).
--   * No wallets / user_points / user_investments / transactions schema / KSP /
--     Daily Profit / deposits-withdrawals formulas / FCM / notifications / RLS
--     changed. Only the two listed functions are recreated.
--   * The only commission-dup protection remains the existing idempotency inside
--     fn_process_agent_commission (agent_commissions.transaction_id unique + the
--     fn's own pre-check). No second competing commission mechanism is introduced.
--   * All authorization checks, row locks, status transitions, balance mutations,
--     pending-balance logic, audit behavior, notifications, return shapes,
--     SECURITY DEFINER, and grants preserved untouched.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. agent_approve_deposit
--
-- Change vs authoritative 20260715000000:
--   BEFORE:  Step 7 called  fn_process_agent_commission(v_agent_id)
--            -> wrong arg (agent UUID) AND tx still 'pending' -> commission skipped.
--   AFTER :  Commission moved to run AFTER status='completed' update, using the
--            correct transaction id:
--              v_commission := public.fn_process_agent_commission(p_transaction_id);
--   Everything else (auth, locks, wallet/agent updates, notifications, audit,
--   return shape) is reproduced verbatim.
-- -----------------------------------------------------------------------------
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
  -- Step 1: Auth check
  RAISE LOG '[DEPOSIT_APPROVE] Start. tx=%, auth.uid=%', p_transaction_id, v_agent_user_id;

  IF v_agent_user_id IS NULL THEN
    RAISE LOG '[DEPOSIT_APPROVE] Unauthorized (auth.uid is NULL)';
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  -- Step 2: Resolve agent
  SELECT a.id INTO v_agent_id
    FROM agents a
    WHERE a.user_id = v_agent_user_id AND a.status = 'active';

  RAISE LOG '[DEPOSIT_APPROVE] agent_id=% (from user_id=%)', v_agent_id, v_agent_user_id;

  IF v_agent_id IS NULL THEN
    RAISE LOG '[DEPOSIT_APPROVE] Agent not found or inactive for user_id=%', v_agent_user_id;
    RETURN json_build_object('success', false, 'message', 'Agent not found or inactive');
  END IF;

  -- Step 3: Get agent name
  SELECT COALESCE(p.full_name, 'Agent') INTO v_agent_name
    FROM profiles p WHERE p.id = v_agent_user_id;

  -- Step 4: Find & lock transaction (EXPLICIT TEXT CAST)
  RAISE LOG '[DEPOSIT_APPROVE] Looking for tx: id=%, type=deposit, status IN (pending,processing), reference_id=% (agent_id::TEXT)',
    p_transaction_id, v_agent_id::TEXT;

  SELECT * INTO v_tx
    FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT
      AND type = 'deposit'
      AND status IN ('pending', 'processing')
    FOR UPDATE;

  IF NOT FOUND THEN
    SELECT reference_id, status, type
      INTO v_debug_ref, v_debug_status, v_debug_type
      FROM transactions WHERE id = p_transaction_id;

    IF v_debug_ref IS NULL AND v_debug_status IS NULL THEN
      RAISE LOG '[DEPOSIT_APPROVE] Transaction % does not exist at all', p_transaction_id;
    ELSE
      RAISE LOG '[DEPOSIT_APPROVE] Transaction exists but no match. ref=% (expected=%), status=% (expected pending/processing), type=% (expected deposit)',
        v_debug_ref, v_agent_id::TEXT, v_debug_status, v_debug_type;
    END IF;

    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  RAISE LOG '[DEPOSIT_APPROVE] Transaction found. id=%, user_id=%, amount=%, status=%',
    v_tx.id, v_tx.user_id, v_tx.amount, v_tx.status;

  -- Step 5: Lock wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE LOG '[DEPOSIT_APPROVE] Wallet not found for wallet_id=%', v_tx.wallet_id;
    RETURN json_build_object('success', false, 'message', 'Wallet not found');
  END IF;

  -- Step 6: Get user name
  SELECT COALESCE(full_name, 'User') INTO v_user_name
    FROM profiles WHERE id = v_tx.user_id;

  -- Step 7: Update transaction (mark completed BEFORE commission processing)
  UPDATE transactions SET
    status = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW(),
    running_balance = v_wallet.available_balance + v_tx.amount
    WHERE id = p_transaction_id;

  -- Step 8: Process commission AFTER completion (P1-3 fix)
  --   Correct transaction id + tx.status = 'completed' so fn_process_agent_commission
  --   can resolve and credit the agent commission (deposit 1.0%) exactly once.
  BEGIN
    v_commission := public.fn_process_agent_commission(p_transaction_id);
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[DEPOSIT_APPROVE] Commission processing failed: %', SQLERRM;
    v_commission := json_build_object('warning', 'Commission processing failed: ' || SQLERRM);
  END;

  -- Step 9: Update wallet
  UPDATE wallets SET
    available_balance = available_balance + v_tx.amount,
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
    updated_at = NOW()
    WHERE id = v_tx.wallet_id;

  -- Step 10: Update agent stats
  UPDATE agents SET
    total_transactions = total_transactions + 1,
    last_active_at = NOW()
    WHERE id = v_agent_id;

  -- Step 11: Notifications
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
    RAISE LOG '[DEPOSIT_APPROVE] User notification failed: %', SQLERRM;
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
    RAISE LOG '[DEPOSIT_APPROVE] Admin notification failed: %', SQLERRM;
  END;

  -- Step 12: Audit
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
    RAISE LOG '[DEPOSIT_APPROVE] Audit log failed: %', SQLERRM;
  END;

  RAISE LOG '[DEPOSIT_APPROVE] SUCCESS. tx=%, agent=%, user=%', p_transaction_id, v_agent_id, v_tx.user_id;

  RETURN json_build_object(
    'success', true,
    'transaction_id', p_transaction_id,
    'commission', v_commission
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 2. agent_confirm_withdrawal
--
-- Change vs authoritative 20260715000000 (which had NO commission at all):
--   Add, AFTER the transaction is marked 'completed':
--     PERFORM public.fn_process_agent_commission(p_transaction_id);
--   This wires the existing 1.5% withdrawal commission for agent-confirmed
--   withdrawals (rate + eligibility already defined in fn_process_agent_commission,
--   and prior agent-withdrawal witnesses wired it; user approved this scope).
--   Wrapped in BEGIN/EXCEPTION (non-fatal) so a commission failure never reverts
--   the withdrawal completion. Everything else reproduced verbatim.
-- -----------------------------------------------------------------------------
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
  -- Step 1: Auth check
  RAISE LOG '[WITHDRAWAL_CONFIRM] Start. tx=%, auth.uid=%', p_transaction_id, v_agent_user_id;

  IF v_agent_user_id IS NULL THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] Unauthorized (auth.uid is NULL)';
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  -- Step 2: Resolve agent
  SELECT a.id INTO v_agent_id
    FROM agents a
    WHERE a.user_id = v_agent_user_id AND a.status = 'active';

  RAISE LOG '[WITHDRAWAL_CONFIRM] agent_id=% (from user_id=%)', v_agent_id, v_agent_user_id;

  IF v_agent_id IS NULL THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] Agent not found or inactive for user_id=%', v_agent_user_id;
    RETURN json_build_object('success', false, 'message', 'Agent not found or inactive');
  END IF;

  -- Step 3: Get agent name
  SELECT COALESCE(p.full_name, 'Agent') INTO v_agent_name
    FROM profiles p WHERE p.id = v_agent_user_id;

  -- Step 4: Find & lock transaction (EXPLICIT TEXT CAST)
  RAISE LOG '[WITHDRAWAL_CONFIRM] Looking for tx: id=%, type=withdrawal, status IN (pending,processing), reference_id=% (agent_id::TEXT)',
    p_transaction_id, v_agent_id::TEXT;

  SELECT * INTO v_tx
    FROM transactions
    WHERE id = p_transaction_id
      AND reference_id = v_agent_id::TEXT
      AND type = 'withdrawal'
      AND status IN ('pending', 'processing')
    FOR UPDATE;

  IF NOT FOUND THEN
    SELECT reference_id, status, type
      INTO v_debug_ref, v_debug_status, v_debug_type
      FROM transactions WHERE id = p_transaction_id;

    IF v_debug_ref IS NULL AND v_debug_status IS NULL THEN
      RAISE LOG '[WITHDRAWAL_CONFIRM] Transaction % does not exist at all', p_transaction_id;
    ELSE
      RAISE LOG '[WITHDRAWAL_CONFIRM] Transaction exists but no match. ref=% (expected=%), status=% (expected pending/processing), type=% (expected withdrawal)',
        v_debug_ref, v_agent_id::TEXT, v_debug_status, v_debug_type;
    END IF;

    RETURN json_build_object('success', false, 'message', 'Transaction not found or not authorized');
  END IF;

  RAISE LOG '[WITHDRAWAL_CONFIRM] Transaction found. id=%, user_id=%, amount=%, status=%',
    v_tx.id, v_tx.user_id, v_tx.amount, v_tx.status;

  -- Step 5: Lock wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_tx.wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] Wallet not found for wallet_id=%', v_tx.wallet_id;
    RETURN json_build_object('success', false, 'message', 'Wallet not found');
  END IF;

  -- Step 6: Get user name
  SELECT COALESCE(full_name, 'User') INTO v_user_name
    FROM profiles WHERE id = v_tx.user_id;

  -- Step 7: Update transaction (mark completed)
  UPDATE transactions SET
    status = 'completed',
    processed_by = v_agent_user_id,
    processed_at = NOW()
    WHERE id = p_transaction_id;

  -- Step 7.5: Process commission AFTER completion (P1-3 fix)
  --   Withdrawal commission (1.5%) credited via existing fn_process_agent_commission,
  --   idempotent per transaction. Non-fatal: never reverts the withdrawal.
  BEGIN
    PERFORM public.fn_process_agent_commission(p_transaction_id);
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] Commission processing failed: %', SQLERRM;
  END;

  -- Step 8: Update wallet
  UPDATE wallets SET
    pending_balance = GREATEST(pending_balance - v_tx.amount, 0),
    updated_at = NOW()
    WHERE id = v_tx.wallet_id;

  -- Step 9: Update agent stats
  UPDATE agents SET
    total_transactions = total_transactions + 1,
    last_active_at = NOW()
    WHERE id = v_agent_id;

  -- Step 10: Notify user
  BEGIN
    INSERT INTO notifications (user_id, title, message, type, status, sent_at)
    VALUES (
      v_tx.user_id,
      'تم تأكيد السحب',
      'تم صرف مبلغ $' || v_tx.amount || ' USD بنجاح من قِبل الوكيل ' || v_agent_name,
      'success', 'sent', NOW()
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] User notification failed: %', SQLERRM;
  END;

  -- Step 11: Audit
  BEGIN
    PERFORM public.fn_log_financial_audit(
      v_tx.user_id, 'agent', 'withdrawal_confirmed', p_transaction_id,
      v_tx.status, 'completed', v_tx.amount,
      jsonb_build_object('agent_id', v_agent_id, 'agent_name', v_agent_name)
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE LOG '[WITHDRAWAL_CONFIRM] Audit log failed: %', SQLERRM;
  END;

  RAISE LOG '[WITHDRAWAL_CONFIRM] SUCCESS. tx=%, agent=%, user=%', p_transaction_id, v_agent_id, v_tx.user_id;

  RETURN json_build_object('success', true);
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Grants (preserved; CREATE OR REPLACE keeps grants but re-granting is
--    explicit and matches repo convention in 20260715000000:538-539).
-- -----------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.agent_approve_deposit(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.agent_confirm_withdrawal(UUID) TO authenticated;
