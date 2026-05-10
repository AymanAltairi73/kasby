-- ==============================================================================
-- KASBY - FIX PROFILE NOT CREATED ON SIGNUP
-- ==============================================================================
-- Problem: New users register successfully but NO profile row is created.
-- Diagnosis: The trigger `on_auth_user_created` may have been dropped
--            or the function `handle_new_user()` was recreated without 
--            re-binding the trigger.
-- ==============================================================================

-- Step 1: Verify the function exists (recreate it to be safe)
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
        v_referral_code := 'K-' || upper(substring(md5(random()::text) from 1 for 5));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = v_referral_code);
    END LOOP;

    -- [C] Insert or UPDATE Profile 
    BEGIN
        INSERT INTO public.profiles (
            id, 
            full_name, 
            email, 
            phone, 
            country_code, 
            referral_code, 
            referred_by
        )
        VALUES (
            NEW.id,
            COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''), 'مستخدم جديد'),
            COALESCE(NULLIF(NEW.email, ''), NEW.raw_user_meta_data ->> 'email', ''),
            COALESCE(NULLIF(NEW.phone, ''), NEW.raw_user_meta_data ->> 'phone'),
            COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
            v_referral_code,
            v_referred_by_id
        )
        ON CONFLICT (id) DO UPDATE SET
            full_name = EXCLUDED.full_name,
            email = EXCLUDED.email,
            phone = EXCLUDED.phone,
            country_code = EXCLUDED.country_code,
            referral_code = COALESCE(public.profiles.referral_code, EXCLUDED.referral_code),
            referred_by = COALESCE(public.profiles.referred_by, EXCLUDED.referred_by);
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

-- Step 2: DROP and RE-CREATE the trigger to ensure it's bound
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Step 3: Verify trigger exists
-- Run this query to confirm:
-- SELECT tgname, tgrelid::regclass, tgfoid::regproc 
-- FROM pg_trigger 
-- WHERE tgname = 'on_auth_user_created';

-- Step 4: Fix existing orphaned user (the one just registered without a profile)
-- Replace the UUID with the actual user ID if needed
INSERT INTO public.profiles (id, full_name, email, phone, country_code, referral_code)
SELECT 
    u.id,
    COALESCE(u.raw_user_meta_data ->> 'full_name', 'مستخدم جديد'),
    COALESCE(u.email, u.raw_user_meta_data ->> 'email', ''),
    COALESCE(u.phone, u.raw_user_meta_data ->> 'phone'),
    u.raw_user_meta_data ->> 'country_code',
    'K-' || upper(substring(md5(random()::text) from 1 for 5))
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

-- Also create wallets for orphaned users
INSERT INTO public.wallets (user_id, currency)
SELECT u.id, 'USD'
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.wallets w WHERE w.user_id = u.id)
ON CONFLICT (user_id, currency) DO NOTHING;

-- Also create points for orphaned users
INSERT INTO public.user_points (user_id)
SELECT u.id
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.user_points up WHERE up.user_id = u.id)
ON CONFLICT (user_id) DO NOTHING;
