-- ==============================================================================
-- KASBY - FIX DEFAULT/EMPTY PROFILE DATA ON SIGNUP
-- ==============================================================================
-- Problem: Users are getting empty Name and Email in their profiles.
-- Cause: Another background trigger is firing FIRST and creating a blank profile.
-- Solution: We will aggressively UPDATE the profile with the correct data
-- if it was already created by the background trigger.
-- ==============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code TEXT;
BEGIN
    -- [A] Resolve Referral (Safely)
    BEGIN
        IF NEW.raw_user_meta_data ->> 'referred_by_code' IS NOT NULL AND NEW.raw_user_meta_data ->> 'referred_by_code' != '' THEN
            SELECT id INTO v_referred_by_id
            FROM public.profiles
            WHERE referral_code = (NEW.raw_user_meta_data ->> 'referred_by_code')
            LIMIT 1;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_referred_by_id := NULL;
    END;

    -- [B] Generate Unique Referral Code
    LOOP
        v_referral_code := 'K-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' || upper(substring(md5(random()::text) from 5 for 4));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = v_referral_code);
    END LOOP;

    -- [C] Insert or AGGRESSIVELY UPDATE Profile 
    -- (This fixes the "default data" issue caused by zombie triggers)
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
            COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''), 'مستخدم جديد'), -- Default if somehow genuinely empty
            COALESCE(NULLIF(NEW.email, ''), NEW.raw_user_meta_data ->> 'email', ''),
            COALESCE(NULLIF(NEW.phone, ''), NEW.raw_user_meta_data ->> 'phone'),
            COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
            v_referral_code,
            v_referred_by_id
        )
        ON CONFLICT (id) DO UPDATE SET
            -- Overwrite whatever the zombie trigger inserted with the correct data
            full_name = EXCLUDED.full_name,
            email = EXCLUDED.email,
            phone = EXCLUDED.phone,
            country_code = EXCLUDED.country_code,
            -- Keep the referral code if the zombie trigger somehow made a valid one
            referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code),
            referred_by_id = COALESCE(public.profiles.referred_by_id, EXCLUDED.referred_by_id);
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user profile insert/update failed: %', SQLERRM;
    END;

    -- [D] Insert Wallet Safely
    BEGIN
        INSERT INTO public.wallets (user_id, currency)
        VALUES (NEW.id, 'USD')
        ON CONFLICT (user_id, currency) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user wallet insert failed: %', SQLERRM;
    END;

    -- [E] Insert Points Safely
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

COMMIT;
