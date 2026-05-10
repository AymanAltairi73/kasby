-- ============================================================
-- KASBY - Fundamental Fix for Signup Database Error
-- Consolidate all new user initialization into a single trigger
-- ============================================================

BEGIN;

-- 1. Drop the profile-level trigger that causes the duplication
DROP TRIGGER IF EXISTS trg_auto_wallet ON public.profiles CASCADE;
DROP FUNCTION IF EXISTS public.fn_create_wallet_for_user() CASCADE;

-- 2. Update the main handle_new_user function to be the Single Source of Truth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code TEXT;
BEGIN
    -- A. Resolve referred_by_code to UUID if provided in metadata
    IF NEW.raw_user_meta_data ->> 'referred_by_code' IS NOT NULL THEN
        SELECT id INTO v_referred_by_id
        FROM public.profiles
        WHERE referral_code = (NEW.raw_user_meta_data ->> 'referred_by_code');
    END IF;

    -- B. Generate a unique referral code
    LOOP
        v_referral_code := 'K-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' || upper(substring(md5(random()::text) from 5 for 4));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = v_referral_code);
    END LOOP;

    -- C. Insert into Profiles
    -- Use ON CONFLICT to prevent crashes if a record somehow exists
    INSERT INTO public.profiles (id, full_name, email, phone, country_code, referral_code, referred_by_id)
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
        full_name = EXCLUDED.full_name,
        phone = COALESCE(profiles.phone, EXCLUDED.phone),
        country_code = COALESCE(profiles.country_code, EXCLUDED.country_code);

    -- D. Create Wallet (ONE PLACE ONLY)
    -- Currency defaults to 'USD' in table schema
    INSERT INTO public.wallets (user_id, currency)
    VALUES (NEW.id, 'USD')
    ON CONFLICT (user_id, currency) DO NOTHING;

    -- E. Create User Points
    INSERT INTO public.user_points (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 3. Ensure the trigger is properly linked to auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

COMMIT;

-- ============================================================
-- DONE: Run the above in Supabase SQL Editor.
-- This removes the redundant 'trg_auto_wallet' and puts all 
-- initialization logic inside 'handle_new_user'.
-- ============================================================
