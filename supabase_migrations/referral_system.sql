-- =============================================
-- Referral System Migration for Supabase
-- =============================================
-- Run this SQL in your Supabase SQL Editor

-- 1. Add referred_by column to profiles (if not exists)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- 2. Create referral_earnings table
CREATE TABLE IF NOT EXISTS referral_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  investor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  investment_id TEXT, -- Used for idempotency (prevent duplicate commissions)
  investment_amount NUMERIC(15, 2) NOT NULL,
  commission_rate NUMERIC(5, 4) NOT NULL DEFAULT 0.02, -- 2%
  commission_amount NUMERIC(15, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Prevent duplicate commission for the same investment
  CONSTRAINT unique_investment_commission UNIQUE (investor_id, investment_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_referral_earnings_referrer ON referral_earnings(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referral_earnings_investor ON referral_earnings(investor_id);
CREATE INDEX IF NOT EXISTS idx_profiles_referred_by ON profiles(referred_by);
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);

-- 3. Enable RLS on referral_earnings
ALTER TABLE referral_earnings ENABLE ROW LEVEL SECURITY;

-- Users can read their own referral earnings (as referrer)
CREATE POLICY "Users can view their referral earnings"
  ON referral_earnings FOR SELECT
  USING (auth.uid() = referrer_id);

-- System can insert (via RPC)
CREATE POLICY "System can insert referral earnings"
  ON referral_earnings FOR INSERT
  WITH CHECK (true);

-- 4. RPC Function: process_referral_commission
-- This function atomically:
--   a) Checks if investor has a referrer
--   b) Ensures no duplicate commission for this investment
--   c) Calculates 2% commission
--   d) Inserts into referral_earnings
--   e) Credits referrer's wallet
--   f) Creates a notification for the referrer
CREATE OR REPLACE FUNCTION process_referral_commission(
  p_investor_id UUID,
  p_investment_amount NUMERIC,
  p_investment_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referrer_id UUID;
  v_commission NUMERIC(15, 2);
  v_investor_name TEXT;
  v_referrer_wallet_id UUID;
  v_commission_rate NUMERIC := 0.02; -- 2%
BEGIN
  -- 1. Get the referrer for this investor
  SELECT referred_by INTO v_referrer_id
  FROM profiles
  WHERE id = p_investor_id;
  
  -- No referrer? Exit gracefully
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'no_referrer');
  END IF;
  
  -- 2. Check for duplicate commission (idempotency)
  IF p_investment_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM referral_earnings
      WHERE investor_id = p_investor_id
        AND investment_id = p_investment_id
    ) THEN
      RETURN jsonb_build_object('success', false, 'message', 'already_processed');
    END IF;
  END IF;
  
  -- 3. Calculate commission
  v_commission := ROUND(p_investment_amount * v_commission_rate, 2);
  
  -- 4. Get investor name for notification
  SELECT full_name INTO v_investor_name
  FROM profiles
  WHERE id = p_investor_id;
  
  -- 5. Insert referral earning record
  INSERT INTO referral_earnings (
    referrer_id,
    investor_id,
    investment_id,
    investment_amount,
    commission_rate,
    commission_amount
  ) VALUES (
    v_referrer_id,
    p_investor_id,
    p_investment_id,
    p_investment_amount,
    v_commission_rate,
    v_commission
  );
  
  -- 6. Credit referrer's wallet
  -- Find the referrer's primary wallet (USD)
  SELECT id INTO v_referrer_wallet_id
  FROM wallets
  WHERE user_id = v_referrer_id
    AND currency = 'USD'
  LIMIT 1;
  
  IF v_referrer_wallet_id IS NOT NULL THEN
    UPDATE wallets
    SET balance = balance + v_commission,
        updated_at = NOW()
    WHERE id = v_referrer_wallet_id;
    
    -- Record the commission as a transaction
    INSERT INTO transactions (
      user_id,
      wallet_id,
      amount,
      type,
      status,
      description,
      created_at
    ) VALUES (
      v_referrer_id,
      v_referrer_wallet_id,
      v_commission,
      'reward',
      'completed',
      'عمولة إحالة من استثمار ' || COALESCE(v_investor_name, 'مستخدم') || ' بقيمة $' || p_investment_amount::TEXT,
      NOW()
    );
  END IF;
  
  -- 7. Create notification for the referrer
  INSERT INTO notifications (
    user_id,
    title,
    message,
    type,
    target,
    target_user_id,
    status,
    sent_at,
    created_at
  ) VALUES (
    v_referrer_id,
    'عمولة إحالة!',
    'لقد حصلت على عمولة $' || v_commission::TEXT || ' من استثمار ' || COALESCE(v_investor_name, 'مستخدم') || ' بقيمة $' || p_investment_amount::TEXT || ' عبر كود الإحالة الخاص بك',
    'success',
    'user',
    v_referrer_id,
    'sent',
    NOW(),
    NOW()
  );
  
  RETURN jsonb_build_object(
    'success', true,
    'commission', v_commission,
    'referrer_name', (SELECT full_name FROM profiles WHERE id = v_referrer_id),
    'message', 'commission_processed'
  );
  
EXCEPTION
  WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'message', 'already_processed');
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'message', SQLERRM);
END;
$$;
