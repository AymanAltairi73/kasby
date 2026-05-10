-- ============================================================================
-- SYSTEM HEALTH FIX: Referrals, Account Recovery & Core Consistency
-- ============================================================================

BEGIN;

-- 1. CONSISTENCY: Ensure Profiles Referral Columns are Unified
-- We prioritize 'referred_by' as the standard column name used in code.
DO $$ 
BEGIN
    -- If referred_by_id exists, move data to referred_by and drop it
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='profiles' AND column_name='referred_by_id') THEN
        UPDATE public.profiles SET referred_by = referred_by_id WHERE referred_by IS NULL AND referred_by_id IS NOT NULL;
        ALTER TABLE public.profiles DROP COLUMN referred_by_id;
    END IF;
    
    -- Ensure referred_by is a proper foreign key
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name='profiles' AND constraint_type='FOREIGN KEY' AND constraint_name='profiles_referred_by_fkey'
    ) THEN
        ALTER TABLE public.profiles ADD CONSTRAINT profiles_referred_by_fkey FOREIGN KEY (referred_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 2. REFERRAL SYSTEM: Earnings Table
CREATE TABLE IF NOT EXISTS public.referral_earnings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    investor_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    investment_amount   NUMERIC(15, 2) NOT NULL,
    commission_amount   NUMERIC(15, 2) NOT NULL,
    investment_id       TEXT, -- For idempotency
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(investor_id, investment_id)
);

CREATE INDEX IF NOT EXISTS idx_referral_earnings_referrer ON referral_earnings(referrer_id);

-- 3. REFERRAL SYSTEM: Commission Processing RPC
CREATE OR REPLACE FUNCTION public.process_referral_commission(
    p_investor_id UUID,
    p_investment_amount NUMERIC,
    p_investment_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_referrer_id UUID;
    v_commission NUMERIC;
    v_referrer_name TEXT;
    v_wallet_id UUID;
BEGIN
    -- 1. Find the referrer
    SELECT referred_by INTO v_referrer_id FROM public.profiles WHERE id = p_investor_id;
    
    IF v_referrer_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'No referrer found for this investor');
    END IF;

    -- 2. Check for duplicate processing
    IF p_investment_id IS NOT NULL AND EXISTS (SELECT 1 FROM referral_earnings WHERE investor_id = p_investor_id AND investment_id = p_investment_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Commission already processed for this investment');
    END IF;

    -- 3. Calculate 2% commission
    v_commission := ROUND(p_investment_amount * 0.02, 2);

    -- 4. Get referrer's wallet (USD)
    SELECT id INTO v_wallet_id FROM public.wallets WHERE user_id = v_referrer_id AND currency = 'USD';
    
    IF v_wallet_id IS NULL THEN
        -- Auto-provision wallet if missing
        INSERT INTO public.wallets (user_id, currency, available_balance)
        VALUES (v_referrer_id, 'USD', v_commission)
        RETURNING id INTO v_wallet_id;
    ELSE
        -- Update existing wallet
        UPDATE public.wallets SET available_balance = available_balance + v_commission, updated_at = NOW()
        WHERE id = v_wallet_id;
    END IF;

    -- 5. Record the earning
    INSERT INTO public.referral_earnings (referrer_id, investor_id, investment_amount, commission_amount, investment_id)
    VALUES (v_referrer_id, p_investor_id, p_investment_amount, v_commission, p_investment_id);

    -- 6. Record transaction
    INSERT INTO public.transactions (user_id, wallet_id, type, amount, status, description)
    VALUES (v_referrer_id, v_wallet_id, 'reward', v_commission, 'completed', 'عمولة إحالة من استثمار صديق');

    -- 7. Notify referrer
    SELECT full_name INTO v_referrer_name FROM public.profiles WHERE id = v_referrer_id;
    INSERT INTO public.notifications (user_id, title, message)
    VALUES (v_referrer_id, 'مكافأة إحالة جديدة', 'لقد حصلت على عمولة بقيمة $' || v_commission || ' لأن أحد أصدقائك قام بالاستثمار!');

    RETURN jsonb_build_object(
        'success', true, 
        'commission', v_commission, 
        'referrer_name', v_referrer_name,
        'message', 'Referral commission processed successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. SECURITY: Account Recovery Helper
CREATE OR REPLACE FUNCTION public.recover_account_by_email(p_email TEXT)
RETURNS JSONB AS $$
DECLARE
    v_profile RECORD;
BEGIN
    SELECT id, email, phone, full_name INTO v_profile FROM public.profiles 
    WHERE LOWER(email) = LOWER(p_email) 
    LIMIT 1;

    IF v_profile IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'No account associated with this email');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', v_profile.id,
        'phone', v_profile.phone,
        'full_name', v_profile.full_name,
        'message', 'Account found'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
