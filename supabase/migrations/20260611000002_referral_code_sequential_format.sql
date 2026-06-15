-- ============================================================================
-- KASBY: Sequential Referral Code System (K0001, K0002, ... K10000+)
-- Date: 2026-06-11
-- Safe, non-breaking migration:
--   - Preserves all user records and UUID-based referral relationships
--   - Does NOT drop or recreate the profiles table
--   - Reassigns referral_code strings only; referred_by/referred_by_id unchanged
-- ============================================================================

-- ── 1. Ensure referrer columns coexist (Flutter uses referred_by_id) ─────────
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS referred_by_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'referred_by'
    ) THEN
        UPDATE public.profiles
        SET referred_by_id = referred_by
        WHERE referred_by_id IS NULL AND referred_by IS NOT NULL;

        UPDATE public.profiles
        SET referred_by = referred_by_id
        WHERE referred_by IS NULL AND referred_by_id IS NOT NULL;
    END IF;
END $$;

-- ── 2. Sequence + formatting helpers ────────────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS public.referral_code_seq
    START WITH 1
    INCREMENT BY 1
    NO MAXVALUE
    CACHE 1;

CREATE OR REPLACE FUNCTION public.format_referral_code(p_seq BIGINT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_seq IS NULL OR p_seq < 1 THEN
        RAISE EXCEPTION 'referral sequence must be >= 1';
    END IF;
    IF p_seq <= 9999 THEN
        RETURN 'K' || LPAD(p_seq::TEXT, 4, '0');
    END IF;
    RETURN 'K' || p_seq::TEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.normalize_referral_code(p_code TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_code TEXT;
BEGIN
    IF p_code IS NULL THEN
        RETURN NULL;
    END IF;
    v_code := UPPER(TRIM(p_code));
    -- Strip legacy hyphen prefix (K-XXXXX → handled via stored uppercase codes post-migration)
    v_code := REPLACE(v_code, '-', '');
    RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_valid_referral_code_format(p_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_code TEXT;
BEGIN
    v_code := public.normalize_referral_code(p_code);
    IF v_code IS NULL OR v_code = '' THEN
        RETURN FALSE;
    END IF;
    RETURN v_code ~ '^K[0-9]{4,}$';
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_sequential_referral_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_seq BIGINT;
    v_code TEXT;
    v_attempts INT := 0;
BEGIN
    LOOP
        v_seq := nextval('public.referral_code_seq');
        v_code := public.format_referral_code(v_seq);
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.profiles WHERE referral_code = v_code
        );
        v_attempts := v_attempts + 1;
        IF v_attempts > 100 THEN
            RAISE EXCEPTION 'Unable to generate unique referral code after 100 attempts';
        END IF;
    END LOOP;
    RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_referrer_by_code(p_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_normalized TEXT;
    v_id UUID;
BEGIN
    v_normalized := public.normalize_referral_code(p_code);
    IF v_normalized IS NULL OR v_normalized = '' THEN
        RETURN NULL;
    END IF;
    SELECT id INTO v_id
    FROM public.profiles
    WHERE referral_code = v_normalized
    LIMIT 1;
    RETURN v_id;
END;
$$;

-- ── 3. Safe data migration: renumber by account creation order ─────────────
DO $$
DECLARE
    v_count BIGINT;
BEGIN
    PERFORM pg_advisory_xact_lock(8675309);

    WITH ordered AS (
        SELECT
            id,
            ROW_NUMBER() OVER (ORDER BY created_at ASC NULLS LAST, id ASC) AS seq_num
        FROM public.profiles
    )
    UPDATE public.profiles p
    SET referral_code = public.format_referral_code(o.seq_num)
    FROM ordered o
    WHERE p.id = o.id;

    SELECT COUNT(*) INTO v_count FROM public.profiles;
    IF v_count > 0 THEN
        PERFORM setval('public.referral_code_seq', v_count, true);
    ELSE
        PERFORM setval('public.referral_code_seq', 1, false);
    END IF;
END $$;

-- ── 4. Signup trigger: DB is sole source of truth for referral codes ────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code TEXT;
    v_referred_code_input TEXT;
BEGIN
    v_referred_code_input := NEW.raw_user_meta_data ->> 'referred_by_code';
    IF v_referred_code_input IS NOT NULL AND TRIM(v_referred_code_input) != '' THEN
        v_referred_by_id := public.resolve_referrer_by_code(v_referred_code_input);
    END IF;

    v_referral_code := public.generate_sequential_referral_code();

    BEGIN
        INSERT INTO public.profiles (
            id,
            full_name,
            email,
            phone,
            country_code,
            referral_code,
            referred_by,
            referred_by_id
        )
        VALUES (
            NEW.id,
            COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''), 'مستخدم جديد'),
            COALESCE(NULLIF(NEW.email, ''), NEW.raw_user_meta_data ->> 'email', ''),
            COALESCE(NULLIF(NEW.phone, ''), NEW.raw_user_meta_data ->> 'phone'),
            COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
            v_referral_code,
            v_referred_by_id,
            v_referred_by_id
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            email = EXCLUDED.email,
            phone = EXCLUDED.phone,
            country_code = EXCLUDED.country_code,
            referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code),
            referred_by = COALESCE(public.profiles.referred_by, EXCLUDED.referred_by),
            referred_by_id = COALESCE(public.profiles.referred_by_id, EXCLUDED.referred_by_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user profile insert/update failed: %', SQLERRM;
    END;

    BEGIN
        INSERT INTO public.wallets (user_id, currency)
        VALUES (NEW.id, 'USD')
        ON CONFLICT (user_id, currency) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user wallet insert failed: %', SQLERRM;
    END;

    BEGIN
        INSERT INTO public.user_points (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user points insert failed: %', SQLERRM;
    END;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 5. Transfer lookup: case-insensitive referral code search ───────────────
CREATE OR REPLACE FUNCTION public.create_transfer(
  p_amount NUMERIC,
  p_receiver_referral_code TEXT,
  p_transfer_type TEXT DEFAULT 'funds',
  p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sender_id UUID := auth.uid();
  v_receiver RECORD;
  v_sender_wallet_id UUID;
  v_receiver_wallet_id UUID;
  v_sender_wallet RECORD;
  v_receiver_wallet RECORD;
  v_tx_out_id UUID;
  v_existing_tx_id UUID;
  v_normalized_code TEXT;
BEGIN
  IF v_sender_id IS NULL THEN RETURN json_build_object('success', false, 'error', 'غير مسجل الدخول'); END IF;
  v_sender_wallet_id := public.ensure_user_wallet(v_sender_id);

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_existing_tx_id
    FROM transactions
    WHERE idempotency_key = p_idempotency_key AND user_id = v_sender_id
    LIMIT 1;
    IF v_existing_tx_id IS NOT NULL THEN
      RETURN json_build_object('success', true, 'message', 'تم تنفيذ هذه العملية مسبقاً', 'transaction_id', v_existing_tx_id);
    END IF;
  END IF;

  v_normalized_code := public.normalize_referral_code(p_receiver_referral_code);
  IF v_normalized_code IS NULL OR NOT public.is_valid_referral_code_format(v_normalized_code) THEN
    RETURN json_build_object('success', false, 'error', 'كود الإحالة غير صالح');
  END IF;

  SELECT id, full_name INTO v_receiver FROM profiles WHERE referral_code = v_normalized_code;
  IF NOT FOUND THEN RETURN json_build_object('success', false, 'error', 'كود الإحالة غير صالح'); END IF;
  IF v_receiver.id = v_sender_id THEN RETURN json_build_object('success', false, 'error', 'لا يمكنك التحويل لنفسك'); END IF;

  v_receiver_wallet_id := public.ensure_user_wallet(v_receiver.id);

  SELECT * INTO v_sender_wallet FROM wallets WHERE id = v_sender_wallet_id FOR UPDATE;
  IF v_sender_wallet.is_frozen THEN RETURN json_build_object('success', false, 'error', 'المحفظة غير متاحة'); END IF;
  IF v_sender_wallet.available_balance < p_amount THEN RETURN json_build_object('success', false, 'error', 'الرصيد غير كافٍ'); END IF;

  SELECT * INTO v_receiver_wallet FROM wallets WHERE id = v_receiver_wallet_id FOR UPDATE;

  UPDATE wallets SET available_balance = available_balance - p_amount WHERE id = v_sender_wallet_id;
  UPDATE wallets SET available_balance = available_balance + p_amount WHERE id = v_receiver_wallet_id;

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id, idempotency_key)
  VALUES (v_sender_id, v_sender_wallet_id, 'transfer_out', p_amount, 'completed', 'تحويل إلى ' || v_receiver.full_name, v_receiver.id, p_idempotency_key)
  RETURNING id INTO v_tx_out_id;

  INSERT INTO transactions (user_id, wallet_id, type, amount, status, description, counterpart_user_id, reference_id)
  VALUES (v_receiver.id, v_receiver_wallet_id, 'transfer_in', p_amount, 'completed', 'تحويل مستلم من مستخدم', v_sender_id, v_tx_out_id::TEXT);

  RETURN json_build_object('success', true, 'message', 'تم التحويل بنجاح', 'transaction_id', v_tx_out_id);
EXCEPTION WHEN OTHERS THEN RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ── 6. Referral commission: support both referrer column names ────────────
CREATE OR REPLACE FUNCTION public.process_referral_commission(
  p_investor_id UUID,
  p_investment_amount NUMERIC,
  p_investment_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer_id UUID;
  v_commission NUMERIC(15, 2);
  v_investor_name TEXT;
  v_referrer_wallet_id UUID;
  v_commission_rate NUMERIC := 0.02;
BEGIN
  SELECT COALESCE(referred_by_id, referred_by) INTO v_referrer_id
  FROM public.profiles
  WHERE id = p_investor_id;

  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'no_referrer');
  END IF;

  IF p_investment_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.referral_earnings
      WHERE investor_id = p_investor_id AND investment_id = p_investment_id
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'already_processed');
    END IF;
  END IF;

  v_commission := ROUND(p_investment_amount * v_commission_rate, 2);

  SELECT full_name INTO v_investor_name FROM public.profiles WHERE id = p_investor_id;

  INSERT INTO public.referral_earnings (
    referrer_id, investor_id, investment_id,
    investment_amount, commission_rate, commission_amount
  ) VALUES (
    v_referrer_id, p_investor_id, p_investment_id,
    p_investment_amount, v_commission_rate, v_commission
  );

  SELECT id INTO v_referrer_wallet_id
  FROM public.wallets
  WHERE user_id = v_referrer_id AND currency = 'USD'
  LIMIT 1;

  IF v_referrer_wallet_id IS NOT NULL THEN
    UPDATE public.wallets
    SET available_balance = available_balance + v_commission,
        updated_at = NOW()
    WHERE id = v_referrer_wallet_id;

    INSERT INTO public.transactions (
      user_id, wallet_id, amount, type, status, description, created_at
    ) VALUES (
      v_referrer_id, v_referrer_wallet_id, v_commission, 'reward', 'completed',
      'عمولة إحالة من استثمار ' || COALESCE(v_investor_name, 'مستخدم') || ' بقيمة $' || p_investment_amount::TEXT,
      NOW()
    );
  END IF;

  PERFORM public.fn_create_notification(
    v_referrer_id,
    'عمولة إحالة!',
    'لقد حصلت على عمولة $' || v_commission::TEXT || ' من استثمار ' || COALESCE(v_investor_name, 'مستخدم'),
    'referral_bonus',
    'referral_earning',
    p_investment_id,
    '/my-team',
    'user',
    'normal'
  );

  RETURN jsonb_build_object(
    'success', true,
    'commission', v_commission,
    'referrer_name', (SELECT full_name FROM public.profiles WHERE id = v_referrer_id),
    'message', 'commission_processed'
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'message', 'already_processed');
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;

-- ── 7. Team RPC: unified referrer column + sequential codes ─────────────────
CREATE OR REPLACE FUNCTION public.get_my_team()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_members json;
    v_total_count INTEGER;
    v_referral_code TEXT;
BEGIN
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT COALESCE(referral_code, '') INTO v_referral_code
    FROM public.profiles
    WHERE id = v_user_id;

    SELECT COUNT(*) INTO v_total_count
    FROM public.profiles
    WHERE COALESCE(referred_by_id, referred_by) = v_user_id;

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json) INTO v_members
    FROM (
        SELECT p.id, p.full_name, p.avatar_url, p.created_at, p.status, p.referral_code,
               (SELECT COUNT(*) FROM public.profiles c
                WHERE COALESCE(c.referred_by_id, c.referred_by) = p.id) AS sub_referrals
        FROM public.profiles p
        WHERE COALESCE(p.referred_by_id, p.referred_by) = v_user_id
        ORDER BY p.created_at DESC
    ) r;

    RETURN json_build_object(
        'success', TRUE,
        'my_referral_code', COALESCE(v_referral_code, ''),
        'total_members', v_total_count,
        'members', v_members
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_sequential_referral_code() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.normalize_referral_code(TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.resolve_referrer_by_code(TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_team() TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_referral_commission(UUID, NUMERIC, TEXT) TO authenticated;
