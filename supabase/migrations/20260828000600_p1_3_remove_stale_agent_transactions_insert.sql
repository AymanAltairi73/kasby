-- =============================================================================
-- P1-3 WITHDRAWAL BLOCKER FIX (approved: remove stale agent_transactions INSERT)
--   File: 20260828000600_p1_3_remove_stale_agent_transactions_insert.sql
--
-- PURPOSE / EVIDENCE:
--   The current LIVE create_withdrawal is out-of-band (not from the migration
--   tree) and contains a vestigial `INSERT INTO agent_transactions (...)` that
--   references a table which:
--     * is NEVER created by any migration (no CREATE/ALTER TABLE),
--     * is NEVER read by any migration or application code,
--     * the agent dashboard's actual data source `fn_get_agent_transactions`
--       reads from `transactions` via reference_id (verified live: HTTP 200),
--     * does not exist in the live DB (runtime: "relation agent_transactions
--       does not exist"; REST: 404 PGRST205).
--   => CONFIRMED STALE / UNSUPPORTED LOGIC. Remove ONLY that INSERT.
--
-- This migration recreates the CURRENT LIVE create_withdrawal body VERBATIM
-- (source of truth = pg_get_functiondef output supplied by the operator) with
-- EXACTLY ONE removal: the `INSERT INTO agent_transactions (...)` statement.
--
-- PRESERVED (verbatim from live):
--   * signature public.create_withdrawal(NUMERIC, UUID, TEXT, TEXT), RETURNS jsonb
--   * SECURITY DEFINER
--   * auth check + Arabic error codes
--   * min amount check
--   * idempotency check (transactions.idempotency_key + user_id)
--   * ensure_user_wallet + wallet FOR UPDATE row lock + frozen-wallet check
--   * fee helper call (v_fee computed, NOT applied - unchanged, out of scope)
--   * balance validation + details JSONB
--   * available_balance -> pending_balance movement
--   * transactions INSERT with reference_id = p_agent_id::TEXT
--   * single user notification
--   * EXCEPTION handler -> unexpected_error
--   * GRANT EXECUTE to authenticated
--
-- NOT changed: agent_transactions table (NOT created), transactions table,
-- fn_process_agent_commission, agent_confirm_withdrawal, agent_approve_deposit,
-- commission rates, wallet/financial formulas, idempotency, notifications,
-- auth, RLS, fee behavior. P0-1 / P1-4 untouched.
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

  -- (REMOVED per approval: stale INSERT INTO agent_transactions ... was never a
  --  created/read table. The agent association lives in transactions.reference_id,
  --  consumed by fn_process_agent_commission and fn_get_agent_transactions.)

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
