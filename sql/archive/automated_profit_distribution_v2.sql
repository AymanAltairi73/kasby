-- ============================================================
-- Automated Profit Distribution System v1.0
-- This script sets up the server-side cron job for profits.
-- ============================================================

-- 1. Enable pg_cron extension (if available/needed)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Add tracking column to user_investments
ALTER TABLE public.user_investments 
ADD COLUMN IF NOT EXISTS last_payout_at TIMESTAMPTZ;

-- 3. The Automated Distribution Function
CREATE OR REPLACE FUNCTION public.process_automated_profits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inv RECORD;
    v_daily_amount NUMERIC;
    v_wallet_id UUID;
    v_plan_name TEXT;
    v_currency TEXT := 'USD';
    v_now TIMESTAMPTZ := NOW();
BEGIN
    -- Loop through active investments that are due for a payout (24h since last or start)
    FOR v_inv IN 
        SELECT 
            ui.*, 
            ip.name_ar as plan_name, 
            ip.duration_days as total_days
        FROM public.user_investments ui
        JOIN public.investment_plans ip ON ui.plan_id = ip.id
        WHERE ui.status = 'active'
          AND v_now >= (COALESCE(ui.last_payout_at, ui.start_date) + INTERVAL '24 hours')
    LOOP
        -- Calculate daily profit
        -- Formula: (Total Expected Profit / Total Days)
        v_daily_amount := ROUND((v_inv.expected_profit / COALESCE(v_inv.total_days, 30))::numeric, 2);
        
        -- Get user wallet ID
        SELECT id INTO v_wallet_id FROM public.wallets 
        WHERE user_id = v_inv.user_id AND currency = v_currency;

        IF v_wallet_id IS NOT NULL AND v_daily_amount > 0 THEN
            
            -- A. Update Wallet (Add to profit_balance AND available_balance)
            UPDATE public.wallets 
            SET available_balance = available_balance + v_daily_amount,
                profit_balance = profit_balance + v_daily_amount,
                updated_at = v_now
            WHERE id = v_wallet_id;

            -- B. Record Transaction
            INSERT INTO public.transactions (
                user_id,
                wallet_id,
                type,
                amount,
                currency,
                status,
                description,
                reference_id,
                processed_at
            ) VALUES (
                v_inv.user_id,
                v_wallet_id,
                'profit',
                v_daily_amount,
                v_currency,
                'completed',
                'ربح يومي من ' || v_inv.plan_name,
                v_inv.id::TEXT,
                v_now
            );

            -- C. Update Investment Status (Track payout)
            UPDATE public.user_investments 
            SET actual_profit = COALESCE(actual_profit, 0) + v_daily_amount,
                last_payout_at = v_now
            WHERE id = v_inv.id;

            -- D. Create Notification record
            INSERT INTO public.notifications (
                user_id,
                title,
                message,
                type,
                target,
                target_user_id,
                status
            ) VALUES (
                v_inv.user_id,
                'أرباحك اليومية وصلت ✅',
                'تم إضافة ربح بقيمة ' || v_daily_amount::TEXT || ' ' || v_currency || ' من استثمار (' || v_inv.plan_name || ') بنجاح.',
                'success',
                'specific',
                v_inv.user_id,
                'sent'
            );

        END IF;

    END LOOP;
END;
$$;

-- 4. Schedule the job (Run every 10 minutes)
-- First, try to remove existing if you are re-running
-- SELECT cron.unschedule('check-and-pay-profits');
SELECT cron.schedule('check-and-pay-profits', '*/10 * * * *', 'SELECT process_automated_profits();');
