-- ============================================================
-- Fix phone-only signup: empty email collides on unique_profile_email
-- ============================================================

-- Backfill existing phone-only profiles that used empty email placeholder
UPDATE public.profiles
SET email = id::TEXT || '@phone.kasby.app'
WHERE email IS NULL OR trim(email) = '';

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code  TEXT;
    v_input_code     TEXT;
    v_email          TEXT;
    v_phone          TEXT;
    v_full_name      TEXT;
BEGIN
    v_input_code := NEW.raw_user_meta_data ->> 'referred_by_code';

    IF v_input_code IS NOT NULL AND trim(v_input_code) <> '' THEN
        BEGIN
            SELECT id INTO v_referred_by_id
            FROM public.profiles
            WHERE public.normalize_referral_code(referral_code) =
                  public.normalize_referral_code(v_input_code)
            LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            v_referred_by_id := NULL;
        END;
    END IF;

    LOOP
        v_referral_code := 'K-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' ||
                           upper(substring(md5(random()::text) from 5 for 4));
        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM public.profiles WHERE referral_code = v_referral_code
        );
    END LOOP;

    v_full_name := COALESCE(
        NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), ''),
        'مستخدم جديد'
    );

    v_email := COALESCE(
        NULLIF(trim(NEW.email), ''),
        NULLIF(trim(NEW.raw_user_meta_data ->> 'email'), '')
    );
    IF v_email IS NULL OR v_email = '' THEN
        v_email := NEW.id::TEXT || '@phone.kasby.app';
    END IF;

    v_phone := COALESCE(
        NULLIF(trim(NEW.phone), ''),
        NULLIF(trim(NEW.raw_user_meta_data ->> 'phone'), '')
    );
    IF v_phone IS NOT NULL AND v_phone <> '' AND left(v_phone, 1) <> '+' THEN
        v_phone := '+' || v_phone;
    END IF;

    BEGIN
        INSERT INTO public.profiles (
            id,
            full_name,
            email,
            phone,
            country_code,
            referral_code,
            referred_by_id
        )
        VALUES (
            NEW.id,
            v_full_name,
            v_email,
            v_phone,
            COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
            v_referral_code,
            v_referred_by_id
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name      = COALESCE(NULLIF(EXCLUDED.full_name, ''), profiles.full_name),
            email          = COALESCE(NULLIF(EXCLUDED.email, ''), profiles.email),
            phone          = COALESCE(EXCLUDED.phone, profiles.phone),
            country_code   = COALESCE(EXCLUDED.country_code, profiles.country_code),
            referral_code  = COALESCE(profiles.referral_code, EXCLUDED.referral_code),
            referred_by_id = COALESCE(profiles.referred_by_id, EXCLUDED.referred_by_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'handle_new_user profile failed: %', SQLERRM;
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
