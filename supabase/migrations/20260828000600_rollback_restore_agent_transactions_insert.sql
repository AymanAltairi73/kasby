-- =============================================================================
-- ROLLBACK for 20260828000600_p1_3_remove_stale_agent_transactions_insert.sql
--   File: 20260828000600_rollback_restore_agent_transactions_insert.sql
--
-- Recreates create_withdrawal to the EXACT current-live body (as captured from
-- pg_get_functiondef before the fix), re-adding the `INSERT INTO agent_transactions`
-- statement that the corrective migration removed. Used ONLY if the fix must be
-- reverted. Requires the agent_transactions table to exist to actually succeed;
-- if it does not, this correct migration recreates the failing live state.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_withdrawal(p_amount numeric, p_agent_id uuid, p_idempotency_key text DEFAULT NULL::text, p_currency text DEFAULT 'USD'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_user_id UUID := auth.uid();
  v_wallet_id UUID;
  v_wallet RECORD;
  v_txn_id UUID;
  v_fee numeric := 0.00;
  v_total_required numeric;
BEGIN
  IF v_user_id IS NULL THEN 
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated', 'message', 'غير مسجل الدخول'); 
  END IF;

  IF p_amount IS NULL OR p_amount < 10.00 THEN
    RETURN jsonb_build_object('success', false, 'error', 'min_withdrawal_error', 'message', 'الحد الأدنى للسحب هو $10.00');
  END IF;

  -- Idempotency check
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) <> '' THEN
    SELECT id INTO v_txn_id FROM transactions WHERE idempotency_key = p_idempotency_key AND user_id = v_user_id LIMIT 1;
    IF v_txn_id IS NOT NULL THEN
      RETURN jsonb_build_object('success', true, 'transaction_id', v_txn_id, 'message', 'طلب السحب مسجل مسبقاً');
    END IF;
  END IF;

  v_wallet_id := public.ensure_user_wallet(v_user_id);

  -- Atomic row-level lock on wallet
  SELECT * INTO v_wallet FROM wallets WHERE id = v_wallet_id FOR UPDATE;
  IF v_wallet.is_frozen THEN 
    RETURN jsonb_build_object('success', false, 'error', 'wallet_frozen', 'message', 'المحفظة مغلقة'); 
  END IF;

  -- Calculate withdrawal fee if helper exists
  BEGIN
    SELECT COALESCE(public.fn_calculate_fee('withdraw', p_amount), 0.00) INTO v_fee;
  EXCEPTION WHEN OTHERS THEN
    v_fee := 0.00;
  END;

  v_total_required := p_amount;

  IF v_wallet.available_balance < v_total_required THEN 
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'insufficient_balance', 
      'message', 'رصيد الكاش المتاح غير كافٍ لإتمام طلب السحب',
      'details', jsonb_build_object(
        'available_balance', v_wallet.available_balance,
        'requested_amount', p_amount,
        'fee', v_fee,
        'total_required', v_total_required
      )
    ); 
  END IF;

  -- Move funds atomically from available_balance to pending_balance
  UPDATE wallets 
  SET available_balance = available_balance - v_total_required,
      pending_balance = pending_balance + v_total_required,
      updated_at = NOW() 
  WHERE id = v_wallet_id;

  -- Record pending withdrawal transaction (reference_id stores p_agent_id::TEXT)
  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, reference_id, idempotency_key)
  VALUES (v_user_id, v_wallet_id, 'withdrawal', p_amount, 'pending', 'طلب سحب رصيد عبر وكيل', p_agent_id::TEXT, p_idempotency_key)
  RETURNING id INTO v_txn_id;

  -- Rollback: restore the stale out-of-band INSERT INTIO agent_transactions
  INSERT INTO agent_transactions (agent_id, user_id, transaction_id, type, amount, status)
  VALUES (p_agent_id, v_user_id, v_txn_id, 'withdrawal', p_amount, 'pending');

  -- Send notification
  PERFORM public.fn_create_notification(
    v_user_id,
    'تم إرسال طلب السحب ⏳',
    'طلب السحب بقيمة $' || p_amount || ' قيد المعالجة من قبل الوكيل.',
    'withdrawal_requested', 'transaction', v_txn_id::TEXT, '/all-transactions'
  );

  RETURN jsonb_build_object(
    'success', true, 
    'transaction_id', v_txn_id, 
    'message', 'تم تقديم طلب السحب بنجاح'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', 'unexpected_error', 'message', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.create_withdrawal(numeric, uuid, text, text) TO authenticated;
