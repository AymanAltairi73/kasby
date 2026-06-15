-- ============================================================================
-- Signup trigger: resolve referral codes with hyphen-normalized matching
-- Run in Supabase Dashboard > SQL Editor (after validate_referral_code_rpc.sql)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code TEXT;
    v_input_code TEXT;
BEGIN
    v_input_code := NEW.raw_user_meta_data ->> 'referred_by_code';

    IF v_input_code IS NOT NULL AND trim(v_input_code) <> '' THEN
        SELECT id INTO v_referred_by_id
        FROM public.profiles
        WHERE public.normalize_referral_code(referral_code) =
              public.normalize_referral_code(v_input_code)
        LIMIT 1;
    END IF;

    LOOP
        v_referral_code := 'K-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' ||
                           upper(substring(md5(random()::text) from 5 for 4));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.profiles WHERE referral_code = v_referral_code
        );
    END LOOP;

    INSERT INTO public.profiles (
        id, full_name, email, phone, country_code, referral_code, referred_by_id
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        COALESCE(NEW.email, ''),
        COALESCE(NEW.phone, NEW.raw_user_meta_data ->> 'phone'),
        COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
        v_referral_code,
        v_referred_by_id
    )
    ON CONFLICT (id) DO UPDATE SET
        referred_by_id = COALESCE(profiles.referred_by_id, EXCLUDED.referred_by_id);

    INSERT INTO public.wallets (user_id, currency)
    VALUES (NEW.id, 'USD')
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;
