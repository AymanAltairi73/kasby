-- ==============================================================================
-- Migration: 20260907000000_notification_localization_system.sql
-- Description: Core database infrastructure for end-to-end notification localization
--              (Arabic ↔ English) across in-app, background, terminated, and FCM.
-- ==============================================================================

-- ─── 1. SCHEMA CHANGES ───

-- Ensure profiles.language exists and is constrained to supported languages
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'ar';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'profiles_language_check'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_language_check CHECK (language IN ('ar', 'en'));
    END IF;
END $$;

-- Ensure device_tokens.language exists
ALTER TABLE public.device_tokens
    ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'ar';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'device_tokens_language_check'
    ) THEN
        ALTER TABLE public.device_tokens
            ADD CONSTRAINT device_tokens_language_check CHECK (language IN ('ar', 'en'));
    END IF;
END $$;

-- Add localization metadata columns to notifications table
ALTER TABLE public.notifications
    ADD COLUMN IF NOT EXISTS title_key TEXT,
    ADD COLUMN IF NOT EXISTS message_key TEXT,
    ADD COLUMN IF NOT EXISTS parameters JSONB;

-- Create index for quick lookup of notifications with localization keys
CREATE INDEX IF NOT EXISTS idx_notifications_keys 
    ON public.notifications (title_key, message_key) 
    WHERE title_key IS NOT NULL;


-- ─── 2. RPC: fn_set_user_language ───

CREATE OR REPLACE FUNCTION public.fn_set_user_language(p_language TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF p_language IS NULL OR p_language NOT IN ('ar', 'en') THEN
        p_language := 'ar';
    END IF;

    -- Update user profile
    UPDATE public.profiles
    SET language = p_language,
        updated_at = NOW()
    WHERE id = v_user_id;

    -- Update all active device tokens for this user
    UPDATE public.device_tokens
    SET language = p_language,
        updated_at = NOW()
    WHERE user_id = v_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_set_user_language(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_set_user_language(TEXT) TO service_role;


-- ─── 3. HELPER: fn_get_notification_translation ───

CREATE OR REPLACE FUNCTION public.fn_get_notification_translation(
    p_key TEXT,
    p_lang TEXT,
    p_params JSONB DEFAULT '{}'::jsonb
)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_template TEXT;
    v_result TEXT;
    v_k TEXT;
    v_v TEXT;
BEGIN
    IF p_key IS NULL OR p_key = '' THEN
        RETURN NULL;
    END IF;

    IF p_lang = 'en' THEN
        CASE p_key
            -- Titles
            WHEN 'notif_daily_profit_received_title' THEN v_template := 'Daily Profits Received ✅';
            WHEN 'notif_new_investment_profit_title' THEN v_template := 'New Investment Profit 💰';
            WHEN 'notif_daily_profits_title' THEN v_template := 'Daily Profit 📈';
            WHEN 'notif_investment_matured_title' THEN v_template := 'Investment Matured 🎉';
            WHEN 'notif_ksp_redeem_success_title' THEN v_template := 'KSP Points Redeemed Successfully';
            WHEN 'notif_transfer_sent_title' THEN v_template := 'Transfer Sent Successfully';
            WHEN 'notif_transfer_received_title' THEN v_template := 'Transfer Received';
            WHEN 'notif_points_sent_title' THEN v_template := 'Points Sent Successfully';
            WHEN 'notif_points_received_title' THEN v_template := 'Points Received';
            WHEN 'notif_deposit_submitted_title' THEN v_template := 'Deposit Request Submitted';
            WHEN 'notif_deposit_approved_title' THEN v_template := 'Deposit Approved';
            WHEN 'notif_withdrawal_submitted_title' THEN v_template := 'Withdrawal Request Submitted';
            WHEN 'notif_withdrawal_confirmed_title' THEN v_template := 'Withdrawal Confirmed';
            WHEN 'notif_loan_approved_title' THEN v_template := '💰 Congratulations!';
            WHEN 'notif_loan_requested_title' THEN v_template := 'Loan Request Submitted 📝';
            WHEN 'notif_loan_repayment_success_title' THEN v_template := 'Repayment Successful';
            WHEN 'notif_kyc_verified_title' THEN v_template := '✅ Account Verified';
            WHEN 'notif_friend_request_title' THEN v_template := 'New Friend Request';
            WHEN 'notif_referral_commission_title' THEN v_template := 'Referral Commission!';
            WHEN 'notif_balance_adjustment_title' THEN v_template := '⚖️ Balance Adjustment';
            WHEN 'notif_account_blocked_title' THEN v_template := '⚠️ Account Notice';
            WHEN 'notif_account_unblocked_title' THEN v_template := '✅ Account Activated';
            WHEN 'notif_account_frozen_title' THEN v_template := 'Account Frozen ⛔';
            WHEN 'notif_chat_message_title' THEN v_template := 'New message from @sender';

            -- Messages
            WHEN 'notif_daily_profit_received_msg' THEN v_template := 'A profit of @amount from (@plan) has been credited successfully.';
            WHEN 'notif_new_investment_profit_msg' THEN v_template := 'A profit of @amount from @plan has been added';
            WHEN 'notif_daily_profits_wallet_msg' THEN v_template := '@amount profit has been added to your wallet.';
            WHEN 'notif_investment_matured_msg' THEN v_template := 'Your investment in @plan has matured and principal of @amount has been returned.';
            WHEN 'notif_ksp_redeem_success_msg' THEN v_template := 'Converted @points KSP and credited @amount to your cash balance.';
            WHEN 'notif_transfer_sent_msg' THEN v_template := 'Transferred @amount to @user';
            WHEN 'notif_transfer_received_msg' THEN v_template := 'Received @amount from @user';
            WHEN 'notif_points_sent_msg' THEN v_template := 'Transferred @amount points to @user';
            WHEN 'notif_points_received_msg' THEN v_template := 'Received @amount points from @user';
            WHEN 'notif_deposit_submitted_msg' THEN v_template := 'Your deposit request of @amount has been submitted for review.';
            WHEN 'notif_deposit_approved_msg' THEN v_template := 'Your deposit of @amount has been approved and added to your wallet.';
            WHEN 'notif_withdrawal_submitted_msg' THEN v_template := 'Your withdrawal request of @amount has been submitted.';
            WHEN 'notif_withdrawal_confirmed_msg' THEN v_template := 'Your withdrawal of @amount has been processed.';
            WHEN 'notif_loan_approved_msg' THEN v_template := 'Your loan request has been approved. Funds have been credited to your wallet.';
            WHEN 'notif_loan_requested_msg' THEN v_template := 'Your loan request of @amount has been submitted and is currently under review.';
            WHEN 'notif_loan_repayment_success_msg' THEN v_template := '@paid has been deducted for loan repayment. Remaining: @remaining';
            WHEN 'notif_kyc_verified_msg' THEN v_template := 'Your account is verified! You can now enjoy all platform features.';
            WHEN 'notif_friend_request_msg' THEN v_template := '@user sent you a friend request.';
            WHEN 'notif_referral_commission_msg' THEN v_template := 'You earned a referral commission of @amount from @user';
            WHEN 'notif_balance_adjustment_msg' THEN v_template := 'The system updated your wallet balance by @amount. Check transactions for details.';
            WHEN 'notif_chat_message_msg' THEN v_template := '@message';
            ELSE
                v_template := NULL;
        END CASE;
    ELSE
        -- Arabic translations
        CASE p_key
            -- Titles
            WHEN 'notif_daily_profit_received_title' THEN v_template := 'أرباح استثمار جديدة 💰';
            WHEN 'notif_new_investment_profit_title' THEN v_template := 'أرباح استثمار جديدة 💰';
            WHEN 'notif_daily_profits_title' THEN v_template := 'أرباح يومية 📈';
            WHEN 'notif_investment_matured_title' THEN v_template := 'اكتمل الاستثمار 🎉';
            WHEN 'notif_ksp_redeem_success_title' THEN v_template := 'تم استبدال نقاط KSP بنجاح';
            WHEN 'notif_transfer_sent_title' THEN v_template := 'تم إرسال التحويل';
            WHEN 'notif_transfer_received_title' THEN v_template := 'تم استلام تحويل';
            WHEN 'notif_points_sent_title' THEN v_template := 'تم إرسال النقاط';
            WHEN 'notif_points_received_title' THEN v_template := 'تم استلام نقاط';
            WHEN 'notif_deposit_submitted_title' THEN v_template := 'تم تقديم طلب الإيداع';
            WHEN 'notif_deposit_approved_title' THEN v_template := 'تمت الموافقة على الإيداع';
            WHEN 'notif_withdrawal_submitted_title' THEN v_template := 'تم تقديم طلب السحب';
            WHEN 'notif_withdrawal_confirmed_title' THEN v_template := 'تم تأكيد السحب';
            WHEN 'notif_loan_approved_title' THEN v_template := '💰 مبروك!';
            WHEN 'notif_loan_requested_title' THEN v_template := 'طلب سلفة قيد المراجعة 📝';
            WHEN 'notif_loan_repayment_success_title' THEN v_template := 'سداد السلفة بنجاح';
            WHEN 'notif_kyc_verified_title' THEN v_template := '✅ تم توثيق الحساب';
            WHEN 'notif_friend_request_title' THEN v_template := 'طلب صداقة جديد';
            WHEN 'notif_referral_commission_title' THEN v_template := 'عمولة إحالة!';
            WHEN 'notif_balance_adjustment_title' THEN v_template := '⚖️ تعديل الرصيد';
            WHEN 'notif_account_blocked_title' THEN v_template := '⚠️ تنبيه حساب';
            WHEN 'notif_account_unblocked_title' THEN v_template := '✅ تم تنشيط الحساب';
            WHEN 'notif_account_frozen_title' THEN v_template := 'تم تجميد الحساب ⛔';
            WHEN 'notif_chat_message_title' THEN v_template := 'رسالة جديدة من @sender';

            -- Messages
            WHEN 'notif_daily_profit_received_msg' THEN v_template := 'تم إضافة ربح بقيمة @amount من استثمار (@plan) بنجاح.';
            WHEN 'notif_new_investment_profit_msg' THEN v_template := 'تمت إضافة ربح بقيمة @amount من @plan';
            WHEN 'notif_daily_profits_wallet_msg' THEN v_template := 'تمت إضافة أرباح بقيمة @amount إلى محفظتك.';
            WHEN 'notif_investment_matured_msg' THEN v_template := 'اكتمل استثمارك في @plan وتمت استعادة رأس المال بقيمة @amount.';
            WHEN 'notif_ksp_redeem_success_msg' THEN v_template := 'تم تحويل @points نقطة وإيداع @amount في رصيدك النقدي.';
            WHEN 'notif_transfer_sent_msg' THEN v_template := 'تم تحويل @amount إلى @user';
            WHEN 'notif_transfer_received_msg' THEN v_template := 'تم تحويل مبلغ @amount إليك من @user';
            WHEN 'notif_points_sent_msg' THEN v_template := 'تم تحويل @amount نقطة إلى @user';
            WHEN 'notif_points_received_msg' THEN v_template := 'تم تحويل @amount نقطة إليك من @user';
            WHEN 'notif_deposit_submitted_msg' THEN v_template := 'تم تقديم طلب إيداع بمبلغ @amount وهو قيد المراجعة.';
            WHEN 'notif_deposit_approved_msg' THEN v_template := 'تمت الموافقة على طلب إيداع بمبلغ @amount وإضافته إلى محفظتك.';
            WHEN 'notif_withdrawal_submitted_msg' THEN v_template := 'تم تقديم طلب سحب بمبلغ @amount وهو قيد المراجعة.';
            WHEN 'notif_withdrawal_confirmed_msg' THEN v_template := 'تم تأكيد وإتمام طلب سحب بمبلغ @amount.';
            WHEN 'notif_loan_approved_msg' THEN v_template := 'تمت الموافقة على طلب السلفة الخاص بك. تم إضافة المبلغ إلى محفظتك.';
            WHEN 'notif_loan_requested_msg' THEN v_template := 'تم استلام طلب السلفة بقيمة @amount وهو قيد المراجعة حالياً.';
            WHEN 'notif_loan_repayment_success_msg' THEN v_template := 'تم خصم @paid لسداد السلفة. المبلغ المتبقي: @remaining';
            WHEN 'notif_kyc_verified_msg' THEN v_template := 'تم توثيق حسابك بنجاح! يمكنك الآن الاستفادة من جميع الميزات.';
            WHEN 'notif_friend_request_msg' THEN v_template := 'أرسل لك @user طلب صداقة.';
            WHEN 'notif_referral_commission_msg' THEN v_template := 'لقد حصلت على عمولة @amount من استثمار @user';
            WHEN 'notif_balance_adjustment_msg' THEN v_template := 'قام النظام بتعديل رصيد محفظتك بمقدار @amount. راجع المعاملات للتفاصيل.';
            WHEN 'notif_chat_message_msg' THEN v_template := '@message';
            ELSE
                v_template := NULL;
        END CASE;
    END IF;

    IF v_template IS NULL THEN
        RETURN NULL;
    END IF;

    v_result := v_template;
    IF p_params IS NOT NULL AND jsonb_typeof(p_params) = 'object' THEN
        FOR v_k, v_v IN SELECT * FROM jsonb_each_text(p_params) LOOP
            v_result := REPLACE(v_result, '@' || v_k, v_v);
        END LOOP;
    END IF;

    RETURN v_result;
END;
$$;


-- ─── 4. TRIGGER FUNCTION: fn_localize_notification_before_insert ───

CREATE OR REPLACE FUNCTION public.fn_localize_notification_before_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_lang TEXT := 'ar';
    v_t_key TEXT := NEW.title_key;
    v_m_key TEXT := NEW.message_key;
    v_params JSONB := COALESCE(NEW.parameters, '{}'::jsonb);
    v_title TEXT := COALESCE(NEW.title, '');
    v_msg TEXT := COALESCE(NEW.message, '');
    v_loc_title TEXT;
    v_loc_msg TEXT;
    v_match TEXT[];
    v_plan_en TEXT;
BEGIN
    -- 1. Fetch user language (safe lookup)
    IF NEW.user_id IS NOT NULL THEN
        SELECT COALESCE(language, 'ar') INTO v_user_lang
        FROM public.profiles
        WHERE id = NEW.user_id;
        IF v_user_lang NOT IN ('ar', 'en') THEN
            v_user_lang := 'ar';
        END IF;
    END IF;

    -- 2. If title_key / message_key are not already set, infer them
    IF v_t_key IS NULL OR v_t_key = '' THEN
        -- Daily Profit / Investment Profits
        IF v_title LIKE '%أرباح استثمار جديدة%' OR v_title LIKE '%New Investment Profit%' OR NEW.type = 'daily_profit' THEN
            v_match := regexp_matches(v_msg, 'تم إضافة ربح بقيمة\s*(\$?[\d\.]+)\s*من استثمار\s*\((.+?)\)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_daily_profit_received_title';
                v_m_key := 'notif_daily_profit_received_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'plan', v_match[2]);
            ELSE
                v_match := regexp_matches(v_msg, 'تمت إضافة ربح بقيمة\s*(\$?[\d\.]+)\s*من\s*(.+)');
                IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                    v_t_key := 'notif_new_investment_profit_title';
                    v_m_key := 'notif_new_investment_profit_msg';
                    v_params := jsonb_build_object('amount', v_match[1], 'plan', v_match[2]);
                ELSE
                    v_match := regexp_matches(v_msg, 'تمت إضافة أرباح بقيمة\s*(\$?[\d\.]+)\s*إلى محفظتك');
                    IF v_match IS NOT NULL AND array_length(v_match, 1) >= 1 THEN
                        v_t_key := 'notif_daily_profits_title';
                        v_m_key := 'notif_daily_profits_wallet_msg';
                        v_params := jsonb_build_object('amount', v_match[1]);
                    END IF;
                END IF;
            END IF;

        -- Investment Matured
        ELSIF v_title LIKE '%اكتمل الاستثمار%' OR v_title LIKE '%Investment Matured%' OR NEW.type = 'investment_matured' THEN
            v_match := regexp_matches(v_msg, 'اكتمل استثمارك في\s*(.+?)\s*وتمت استعادة رأس المال بقيمة\s*(\$?[\d\.]+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_investment_matured_title';
                v_m_key := 'notif_investment_matured_msg';
                v_params := jsonb_build_object('plan', v_match[1], 'amount', v_match[2]);
            END IF;

        -- KSP Points Redeem
        ELSIF v_title LIKE '%نقاط KSP%' OR v_title LIKE '%KSP Points%' OR NEW.type = 'ksp_redeem' OR NEW.type = 'points_redeemed' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل\s*(\d+)\s*نقطة وإيداع\s*(\$?[\d\.]+)\s*في رصيدك النقدي');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_ksp_redeem_success_title';
                v_m_key := 'notif_ksp_redeem_success_msg';
                v_params := jsonb_build_object('points', v_match[1], 'amount', v_match[2]);
            END IF;

        -- Transfers: Cash Sent
        ELSIF v_title = 'تم إرسال التحويل' OR NEW.type = 'transfer_sent' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل\s*(\$?[\d\.]+)\s*(?:USD\s*)?إلى\s*(.+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_transfer_sent_title';
                v_m_key := 'notif_transfer_sent_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'user', v_match[2]);
            END IF;

        -- Transfers: Cash Received
        ELSIF v_title = 'تم استلام تحويل' OR NEW.type = 'transfer_received' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل مبلغ\s*(\$?[\d\.]+)\s*(?:USD\s*)?إليك من\s*(.+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_transfer_received_title';
                v_m_key := 'notif_transfer_received_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'user', v_match[2]);
            END IF;

        -- Transfers: Points Sent
        ELSIF v_title = 'تم إرسال النقاط' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل\s*(\d+)\s*نقطة إلى\s*(.+)');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_t_key := 'notif_points_sent_title';
                v_m_key := 'notif_points_sent_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'user', v_match[2]);
            END IF;

        -- Transfers: Points Received
        ELSIF v_title = 'تم استلام نقاط' THEN
            v_match := regexp_matches(v_msg, 'تم تحويل\s*(\d+)\s*نقطة إليك(?:\s*من\s*(.+))?');
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 1 THEN
                v_t_key := 'notif_points_received_title';
                v_m_key := 'notif_points_received_msg';
                v_params := jsonb_build_object('amount', v_match[1], 'user', COALESCE(v_match[2], 'مستخدم'));
            END IF;

        -- Deposits
        ELSIF v_title LIKE '%Deposit Request Submitted%' OR v_title = 'تم تقديم طلب الإيداع' OR NEW.type = 'deposit_submitted' THEN
            v_t_key := 'notif_deposit_submitted_title';
            v_m_key := 'notif_deposit_submitted_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        ELSIF v_title LIKE '%Deposit Approved%' OR v_title = 'تمت الموافقة على الإيداع' OR NEW.type = 'deposit_approved' THEN
            v_t_key := 'notif_deposit_approved_title';
            v_m_key := 'notif_deposit_approved_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        -- Withdrawals
        ELSIF v_title LIKE '%Withdrawal Request Submitted%' OR v_title = 'تم تقديم طلب السحب' OR NEW.type = 'withdrawal_requested' THEN
            v_t_key := 'notif_withdrawal_submitted_title';
            v_m_key := 'notif_withdrawal_submitted_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        ELSIF v_title LIKE '%Withdrawal Confirmed%' OR v_title LIKE '%Withdrawal Completed%' OR v_title = 'تم تأكيد السحب' OR NEW.type = 'withdrawal_completed' THEN
            v_t_key := 'notif_withdrawal_confirmed_title';
            v_m_key := 'notif_withdrawal_confirmed_msg';
            v_match := regexp_matches(v_msg, '(\$?[\d\.]+)');
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        -- Loans
        ELSIF v_title LIKE '%مبروك%' OR v_title LIKE '%Congratulations%' OR NEW.type = 'loan_approved' THEN
            v_t_key := 'notif_loan_approved_title';
            v_m_key := 'notif_loan_approved_msg';

        ELSIF v_title LIKE '%طلب سلفة%' OR v_title LIKE '%Loan Request%' OR NEW.type = 'loan_requested' THEN
            v_match := regexp_matches(v_msg, 'تم استلام طلب السلفة بقيمة\s*(.+?)\s*وهو قيد المراجعة');
            v_t_key := 'notif_loan_requested_title';
            v_m_key := 'notif_loan_requested_msg';
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('amount', v_match[1]);
            END IF;

        ELSIF v_title = 'تم السداد بنجاح' OR v_title = 'سداد السلفة بنجاح' OR v_title = 'Repayment Successful' OR NEW.type = 'loan_repaid' THEN
            v_match := regexp_matches(v_msg, 'تم خصم\s*(.+?)\s*(?:من رصيدك\s*)?لسداد (?:القرض|السلفة)\.\s*المتبقي:\s*(.+)');
            v_t_key := 'notif_loan_repayment_success_title';
            v_m_key := 'notif_loan_repayment_success_msg';
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_params := jsonb_build_object('paid', v_match[1], 'remaining', v_match[2]);
            END IF;

        -- KYC
        ELSIF v_title LIKE '%توثيق الحساب%' OR v_title LIKE '%Account Verified%' OR NEW.type = 'kyc_verified' THEN
            v_t_key := 'notif_kyc_verified_title';
            v_m_key := 'notif_kyc_verified_msg';

        -- Friend Request
        ELSIF v_title LIKE '%طلب صداقة%' OR v_title LIKE '%Friend Request%' OR NEW.type = 'friend_request' THEN
            v_match := regexp_matches(v_msg, 'أرسل لك\s*(.+?)\s*طلب صداقة');
            v_t_key := 'notif_friend_request_title';
            v_m_key := 'notif_friend_request_msg';
            IF v_match IS NOT NULL THEN
                v_params := jsonb_build_object('user', v_match[1]);
            END IF;

        -- Referral Bonus
        ELSIF v_title LIKE '%عمولة إحالة%' OR v_title LIKE '%Referral Commission%' OR NEW.type = 'referral_bonus' THEN
            v_match := regexp_matches(v_msg, 'عمولة\s*(\$?[\d\.]+)\s*من استثمار\s*(.+)');
            v_t_key := 'notif_referral_commission_title';
            v_m_key := 'notif_referral_commission_msg';
            IF v_match IS NOT NULL AND array_length(v_match, 1) >= 2 THEN
                v_params := jsonb_build_object('amount', v_match[1], 'user', v_match[2]);
            END IF;

        -- Chat
        ELSIF v_title LIKE 'رسالة جديدة من %' THEN
            v_t_key := 'notif_chat_message_title';
            v_m_key := 'notif_chat_message_msg';
            v_params := jsonb_build_object('sender', SUBSTRING(v_title FROM 17), 'message', v_msg);
        END IF;
    END IF;

    -- 3. Plan Name Localization (if English and plan param present)
    IF v_user_lang = 'en' AND v_params ? 'plan' THEN
        SELECT COALESCE(name_en, name_ar) INTO v_plan_en
        FROM public.investment_plans
        WHERE name_ar = (v_params->>'plan') OR name_en = (v_params->>'plan')
        LIMIT 1;

        IF v_plan_en IS NOT NULL AND v_plan_en <> '' THEN
            v_params := jsonb_set(v_params, '{plan}', to_jsonb(v_plan_en));
        END IF;
    END IF;

    -- 4. Set keys & parameters on NEW row
    IF v_t_key IS NOT NULL THEN
        NEW.title_key := v_t_key;
    END IF;
    IF v_m_key IS NOT NULL THEN
        NEW.message_key := v_m_key;
    END IF;
    IF v_params IS NOT NULL AND v_params <> '{}'::jsonb THEN
        NEW.parameters := v_params;
    END IF;

    -- 5. Localize title & message into user's language
    IF v_t_key IS NOT NULL THEN
        v_loc_title := public.fn_get_notification_translation(v_t_key, v_user_lang, v_params);
        IF v_loc_title IS NOT NULL AND v_loc_title <> '' THEN
            NEW.title := v_loc_title;
        END IF;
    END IF;

    IF v_m_key IS NOT NULL THEN
        v_loc_msg := public.fn_get_notification_translation(v_m_key, v_user_lang, v_params);
        IF v_loc_msg IS NOT NULL AND v_loc_msg <> '' THEN
            NEW.message := v_loc_msg;
        END IF;
    END IF;

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Safety guard: NEVER fail the INSERT if translation has any issue
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS "trg_localize_notification" ON public.notifications;
CREATE TRIGGER "trg_localize_notification"
    BEFORE INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_localize_notification_before_insert();


-- ─── 5. UPDATE trigger_generic_notification (FCM DATA PAYLOAD) ───

CREATE OR REPLACE FUNCTION "public"."trigger_generic_notification"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_recipient_fcm_token TEXT;
    v_project_url TEXT := 'https://your-project.supabase.co';
    v_service_key TEXT := 'YOUR_SERVICE_ROLE_KEY_HERE';
    v_fcm_secret TEXT := 'YOUR_FCM_SECRET_HERE';
    v_auth_token TEXT;
BEGIN
    -- 1. Try profiles.fcm_token
    SELECT fcm_token INTO v_recipient_fcm_token FROM public.profiles WHERE id = NEW.user_id;

    -- 2. Fallback to active token in device_tokens if profile token is empty
    IF v_recipient_fcm_token IS NULL OR LENGTH(TRIM(v_recipient_fcm_token)) < 10 THEN
        SELECT token INTO v_recipient_fcm_token
        FROM public.device_tokens
        WHERE user_id = NEW.user_id AND is_active = TRUE
        ORDER BY updated_at DESC LIMIT 1;
    END IF;
    
    IF v_recipient_fcm_token IS NOT NULL AND LENGTH(TRIM(v_recipient_fcm_token)) > 10 THEN
        v_auth_token := COALESCE(v_fcm_secret, v_service_key);
        
        BEGIN
            PERFORM net.http_post(
                url := v_project_url || '/functions/v1/send-fcm',
                headers := jsonb_build_object(
                    'Content-Type', 'application/json',
                    'Authorization', 'Bearer ' || v_auth_token
                ),
                body := jsonb_build_object(
                    'token', v_recipient_fcm_token,
                    'title', COALESCE(NEW.title, 'Kasby Notification'),
                    'body', COALESCE(NEW.message, ''),
                    'data', jsonb_build_object(
                        'id', NEW.id::TEXT,
                        'type', COALESCE(NEW.type, 'notification'),
                        'entity_type', COALESCE(NEW.entity_type, ''),
                        'entity_id', COALESCE(NEW.entity_id, ''),
                        'route', COALESCE(NEW.deep_link, '/my-investments'),
                        'deep_link', COALESCE(NEW.deep_link, '/my-investments'),
                        'role_target', COALESCE(NEW.role_target, 'user'),
                        'title_key', COALESCE(NEW.title_key, ''),
                        'message_key', COALESCE(NEW.message_key, ''),
                        'parameters', COALESCE(NEW.parameters::TEXT, '{}')
                    )
                )
            );
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Generic notification FCM trigger failed: %', SQLERRM;
        END;
    END IF;
    RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."trigger_generic_notification"() OWNER TO "postgres";

DROP TRIGGER IF EXISTS "on_notification_inserted" ON "public"."notifications";
CREATE TRIGGER "on_notification_inserted" 
    AFTER INSERT ON "public"."notifications" 
    FOR EACH ROW 
    EXECUTE FUNCTION "public"."trigger_generic_notification"();
