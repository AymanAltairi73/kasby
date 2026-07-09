-- Fix duplicate create_transfer / create_withdrawal RPC overloads (PGRST203)
-- and make fn_get_effective_ksp read-only (no INSERT inside STABLE context).

DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.create_transfer(NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.create_withdrawal(NUMERIC, UUID);
DROP FUNCTION IF EXISTS public.create_withdrawal(NUMERIC, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.fn_get_effective_ksp(p_user_id UUID DEFAULT auth.uid())
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_user_id UUID := COALESCE(p_user_id, auth.uid());
  v_wallet_usd NUMERIC(18, 4);
  v_wallet_ksp BIGINT;
  v_reward_ksp BIGINT;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Unauthorized');
  END IF;

  SELECT COALESCE(w.available_balance, 0)
    INTO v_wallet_usd
    FROM public.wallets w
   WHERE w.user_id = v_user_id
     AND w.currency = 'USD'
   LIMIT 1;

  v_wallet_usd := COALESCE(v_wallet_usd, 0);
  v_wallet_ksp := FLOOR(v_wallet_usd * 1000)::BIGINT;

  SELECT COALESCE(up.current_balance, 0)::BIGINT
    INTO v_reward_ksp
    FROM public.user_points up
   WHERE up.user_id = v_user_id
   LIMIT 1;

  v_reward_ksp := COALESCE(v_reward_ksp, 0);

  RETURN jsonb_build_object(
    'success', true,
    'wallet_usd', v_wallet_usd,
    'wallet_ksp', v_wallet_ksp,
    'reward_ksp', v_reward_ksp,
    'effective_ksp', v_wallet_ksp + v_reward_ksp
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_get_effective_ksp(UUID) TO authenticated;
