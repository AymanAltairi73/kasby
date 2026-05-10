-- ============================================================
-- KASBY - FINAL PEACE FIX (Signup Duplication Removal)
-- This script cleans up ALL redundant triggers and functions
-- to ensure signup works perfectly without 'profiles_pkey' errors.
-- ============================================================

BEGIN;

-- 1. DROP ALL POSSIBLE CONFLICTING TRIGGERS (Cleanup)
-- Cleanup triggers on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP TRIGGER IF EXISTS trg_on_signup ON auth.users CASCADE;
DROP TRIGGER IF EXISTS trg_create_profile_on_signup ON auth.users CASCADE;
DROP TRIGGER IF EXISTS trg_on_auth_signup ON auth.users CASCADE;

-- Cleanup triggers on public.profiles
DROP TRIGGER IF EXISTS trg_auto_wallet ON public.profiles CASCADE;
DROP TRIGGER IF EXISTS trg_create_wallet_for_user ON public.profiles CASCADE;
DROP TRIGGER IF EXISTS trg_on_profile_created ON public.profiles CASCADE;

-- 2. DROP REDUNDANT FUNCTIONS
DROP FUNCTION IF EXISTS public.fn_create_wallet_for_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user_master() CASCADE;

-- 3. CREATE THE UNIFIED INITIALIZATION FUNCTION (One place for everything)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code TEXT;
BEGIN
    -- [A] Resolve Referral ID
    IF NEW.raw_user_meta_data ->> 'referred_by_code' IS NOT NULL THEN
        SELECT id INTO v_referred_by_id
        FROM public.profiles
        WHERE referral_code = (NEW.raw_user_meta_data ->> 'referred_by_code');
    END IF;

    -- [B] Generate Referral Code
    LOOP
        v_referral_code := 'K-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' || upper(substring(md5(random()::text) from 5 for 4));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = v_referral_code);
    END LOOP;

    -- [C] INSERT PROFILE (Idempotent using ON CONFLICT)
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
    ON CONFLICT (id) DO NOTHING;

    -- [D] INSERT WALLET (Idempotent)
    -- Currency defaults to 'USD' in the wallets table schema normally
    INSERT INTO public.wallets (user_id, currency)
    VALUES (NEW.id, 'USD')
    ON CONFLICT (user_id, currency) DO NOTHING;

    -- [E] INSERT USER POINTS (Idempotent)
    INSERT INTO public.user_points (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. CREATE THE SINGLE MASTER TRIGGER
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

COMMIT;

-- ============================================================
-- SUCCESS: The duplication cycle is broken.
-- Run this in Supabase SQL Editor to fix the signup error.
-- ============================================================
