-- ============================================================
-- KASBY – Revamped Seed Data (Fixed UUID Version)
-- Compatible with kasby.sql schema v3.1 (JSONB + ENUMs)
-- ============================================================

-- ============================================================
-- 1. AUTH USERS (1 Admin + 10 New Iraqi Users)
-- ============================================================
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, raw_app_meta_data, created_at, updated_at)
VALUES
  -- Admin
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'master@kasby.com', crypt('Admin@2026!Kasby', gen_salt('bf')), NOW(), '{"full_name":"المشرف العام","is_admin":true}', '{"is_admin":true}', NOW(), NOW()),
  -- Users
  ('a1111111-b111-4111-8111-c11111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'karar.altaie@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"كرار الطائي","country_code":"IQ","phone":"+9647700001"}', '{"provider":"email"}', NOW() - INTERVAL '60 days', NOW()),
  ('a2222222-b222-4222-8222-c22222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mariam.baghdadi@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"مريم البغدادي","country_code":"IQ","phone":"+9647800002"}', '{"provider":"email"}', NOW() - INTERVAL '55 days', NOW()),
  ('a3333333-b333-4333-8333-c33333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'laith.erbil@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"ليث الكردي","country_code":"IQ","phone":"+9647500003"}', '{"provider":"email"}', NOW() - INTERVAL '40 days', NOW()),
  ('a4444444-b444-4444-8444-c44444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'noor.basra@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"نور البصرية","country_code":"IQ","phone":"+9647900004"}', '{"provider":"email"}', NOW() - INTERVAL '30 days', NOW()),
  ('a5555555-b555-4555-8555-c55555555555', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hassan.najaf@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"حسن النجفي","country_code":"IQ","phone":"+9647700005"}', '{"provider":"email"}', NOW() - INTERVAL '25 days', NOW()),
  ('a6666666-b666-4666-8666-c66666666666', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'zainab.karbala@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"زينب الحسينية","country_code":"IQ","phone":"+9647800006"}', '{"provider":"email"}', NOW() - INTERVAL '20 days', NOW()),
  ('a7777777-b777-4777-8777-c77777777777', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ali.mosul@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"علي المصلاوي","country_code":"IQ","phone":"+9647700007"}', '{"provider":"email"}', NOW() - INTERVAL '15 days', NOW()),
  ('a8888888-b888-4888-8888-c88888888888', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'huda.hilla@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"هدى الحلية","country_code":"IQ","phone":"+9647800008"}', '{"provider":"email"}', NOW() - INTERVAL '10 days', NOW()),
  ('a9999999-b999-4999-8999-c99999999999', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'omar.anbar@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"عمر الأنباري","country_code":"IQ","phone":"+9647700009"}', '{"provider":"email"}', NOW() - INTERVAL '5 days', NOW()),
  ('a1010101-b101-4101-8101-c10101010101', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'sara.kirkuk@gmail.com', crypt('Kasby@2026!', gen_salt('bf')), NOW(), '{"full_name":"سارة الكركوكية","country_code":"IQ","phone":"+9647800010"}', '{"provider":"email"}', NOW() - INTERVAL '2 days', NOW())
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
SELECT id, id, email, 'email', jsonb_build_object('sub', id::text, 'email', email), NOW(), created_at, NOW()
FROM auth.users ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. ADMIN PROFILE
-- ============================================================
INSERT INTO admin_profiles (id, full_name, role, is_active)
VALUES ('00000000-0000-0000-0000-000000000000', 'المشرف الرئيسي', 'superadmin', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 3. USER PROFILES
-- ============================================================
UPDATE profiles SET full_name='كرار الطائي', province='بغداد', city='المنصور', account_tier='vip'::account_tier, kyc_status='verified'::kyc_status, referral_code='K-BAGH-01' WHERE id='a1111111-b111-4111-8111-c11111111111';
UPDATE profiles SET full_name='مريم البغدادي', province='بغداد', city='الكرادة', account_tier='verified'::account_tier, kyc_status='verified'::kyc_status, referral_code='K-BAGH-02' WHERE id='a2222222-b222-4222-8222-c22222222222';
UPDATE profiles SET full_name='ليث الكردي', province='أربيل', city='عينكاوا', account_tier='vip'::account_tier, kyc_status='verified'::kyc_status, referral_code='K-ERBIL-01' WHERE id='a3333333-b333-4333-8333-c33333333333';
UPDATE profiles SET full_name='نور البصرية', province='البصرة', city='الجزائر', account_tier='verified'::account_tier, kyc_status='verified'::kyc_status, referral_code='K-BASRA-01' WHERE id='a4444444-b444-4444-8444-c44444444444';
UPDATE profiles SET full_name='حسن النجفي', province='النجف', city='حي السعد', account_tier='free'::account_tier, kyc_status='pending'::kyc_status, referral_code='K-NAJAF-01' WHERE id='a5555555-b555-4555-8555-c55555555555';
UPDATE profiles SET full_name='زينب الحسينية', province='كربلاء', city='حي العباس', account_tier='verified'::account_tier, kyc_status='verified'::kyc_status, referral_code='K-KARB-01' WHERE id='a6666666-b666-4666-8666-c66666666666';
UPDATE profiles SET full_name='علي المصلاوي', province='نينوى', city='الموصل', account_tier='free'::account_tier, kyc_status='unverified'::kyc_status, referral_code='K-MOSUL-01' WHERE id='a7777777-b777-4777-8777-c77777777777';
UPDATE profiles SET full_name='هدى الحلية', province='بابل', city='الحلة', account_tier='free'::account_tier, kyc_status='unverified'::kyc_status, referral_code='K-HILL-01' WHERE id='a8888888-b888-4888-8888-c88888888888';
UPDATE profiles SET full_name='عمر الأنباري', province='الأنبار', city='الرمادي', account_tier='free'::account_tier, kyc_status='pending'::kyc_status, referral_code='K-ANBAR-01' WHERE id='a9999999-b999-4999-8999-c99999999999';
UPDATE profiles SET full_name='سارة الكركوكية', province='كركوك', city='طريق بغداد', account_tier='free'::account_tier, kyc_status='unverified'::kyc_status, referral_code='K-KIRK-01' WHERE id='a1010101-b101-4101-8101-c10101010101';

-- ============================================================
-- 4. WALLETS (Various Balances)
-- ============================================================
UPDATE wallets SET available_balance=15000.0, profit_balance=4500.0, invested_balance=10000.0 WHERE user_id='a1111111-b111-4111-8111-c11111111111';
UPDATE wallets SET available_balance=2500.0, profit_balance=350.0, invested_balance=2000.0 WHERE user_id='a2222222-b222-4222-8222-c22222222222';
UPDATE wallets SET available_balance=32000.0, profit_balance=8700.0, invested_balance=25000.0 WHERE user_id='a3333333-b333-4333-8333-c33333333333';
UPDATE wallets SET available_balance=800.0, profit_balance=120.0, invested_balance=500.0 WHERE user_id='a4444444-b444-4444-8444-c44444444444';
UPDATE wallets SET available_balance=200.0, profit_balance=0.0 WHERE user_id='a5555555-b555-4555-8555-c55555555555';

-- ============================================================
-- 5. INVESTMENT PLANS
-- ============================================================
INSERT INTO investment_plans (id, name_ar, name_en, profit_percentage, duration_days, min_amount, risk_level, is_active) VALUES
  ('f0f0f0f0-f0f0-4f0f-8f0f-f0f0f0f0f0f0', 'الصندوق الذهبي العراقي', 'Iraqi Gold Fund', 12.0, 90, 5000, 'low', true),
  ('f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1', 'مشروع عقارات بغداد', 'Baghdad Real Estate', 15.0, 180, 10000, 'medium', true),
  ('f2f2f2f2-f2f2-4f2f-8f2f-f2f2f2f2f2f2', 'تطوير الزراعة في البصرة', 'Basra Agriculture', 8.5, 60, 1000, 'low', true)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 6. USER INVESTMENTS
-- ============================================================
INSERT INTO user_investments (user_id, plan_id, amount, profit_percentage, expected_profit, status, start_date) VALUES
  ('a1111111-b111-4111-8111-c11111111111', 'f0f0f0f0-f0f0-4f0f-8f0f-f0f0f0f0f0f0', 10000, 12.0, 1200, 'active'::investment_status, NOW() - INTERVAL '30 days'),
  ('a3333333-b333-4333-8333-c33333333333', 'f1f1f1f1-f1f1-4f1f-8f1f-f1f1f1f1f1f1', 25000, 15.0, 3750, 'active'::investment_status, NOW() - INTERVAL '15 days')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 7. TRANSACTIONS
-- ============================================================
INSERT INTO transactions (user_id, wallet_id, type, amount, status, running_balance, description)
SELECT p.id, w.id, 'deposit'::txn_type, 15000.0, 'completed'::txn_status, 15000.0, 'إيداع نقدي أولي' 
FROM profiles p JOIN wallets w ON w.user_id = p.id WHERE p.id='a1111111-b111-4111-8111-c11111111111' ON CONFLICT DO NOTHING;

INSERT INTO transactions (user_id, wallet_id, type, amount, status, running_balance, description)
SELECT p.id, w.id, 'deposit'::txn_type, 32000.0, 'completed'::txn_status, 32000.0, 'تحويل بنكي - مصرف التجارة' 
FROM profiles p JOIN wallets w ON w.user_id = p.id WHERE p.id='a3333333-b333-4333-8333-c33333333333' ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. AGENTS (Ensure Schema & Comprehensive Data)
-- ============================================================

-- Ensure missing columns exist in the agents table
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='user_id') THEN
        ALTER TABLE agents ADD COLUMN user_id UUID REFERENCES profiles(id);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='name') THEN
        ALTER TABLE agents ADD COLUMN name TEXT NOT NULL DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='country') THEN
        ALTER TABLE agents ADD COLUMN country TEXT DEFAULT 'العراق';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='province') THEN
        ALTER TABLE agents ADD COLUMN province TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='city') THEN
        ALTER TABLE agents ADD COLUMN city TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='address') THEN
        ALTER TABLE agents ADD COLUMN address TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='phone') THEN
        ALTER TABLE agents ADD COLUMN phone TEXT NOT NULL DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='whatsapp') THEN
        ALTER TABLE agents ADD COLUMN whatsapp TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='telegram') THEN
        ALTER TABLE agents ADD COLUMN telegram TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='email') THEN
        ALTER TABLE agents ADD COLUMN email TEXT DEFAULT '';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='status') THEN
        ALTER TABLE agents ADD COLUMN status TEXT NOT NULL DEFAULT 'active';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='is_available_now') THEN
        ALTER TABLE agents ADD COLUMN is_available_now BOOLEAN DEFAULT true;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='supported_methods') THEN
        ALTER TABLE agents ADD COLUMN supported_methods JSONB DEFAULT '[]'::JSONB;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='success_rate') THEN
        ALTER TABLE agents ADD COLUMN success_rate NUMERIC(5,2) DEFAULT 0.00;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='agents' AND column_name='total_transactions') THEN
        ALTER TABLE agents ADD COLUMN total_transactions INT DEFAULT 0;
    END IF;
END $$;

-- Insert Agents
INSERT INTO agents (name, country, province, city, address, phone, whatsapp, telegram, email, status, is_available_now, supported_methods, success_rate, total_transactions) VALUES
  ('صيرفة بغداد الحديثة', 'العراق', 'بغداد', 'المنصور', 'شارع 14 رمضان - قرب مطعم روتانا', '+9647710001001', '9647710001001', 'baghdad_modern_cash', 'baghdad@kasby-agents.com', 'active', true, '["zain_cash", "cash", "bank_transfer"]', 98.50, 1240),
  ('مكتب الفاو للحوالات', 'العراق', 'البصرة', 'العشار', 'شارع الساحل - مقابل المكتبة المركزية', '+9647910002002', '9647910002002', 'fao_exchange_basra', 'basra@kasby-agents.com', 'active', true, '["cash", "fast_pay"]', 96.20, 850),
  ('شركة قلعة أربيل', 'العراق', 'أربيل', 'عينكاوا', 'طريق المطار - مبنى القلعة التجاري', '+9647510003003', '9647510003003', 'erbil_citadel_exchange', 'erbil@kasby-agents.com', 'active', true, '["cash", "bank_transfer", "first_pay"]', 99.10, 2100),
  ('صيرفة وادي الرافدين', 'العراق', 'نينوى', 'الموصل', 'الجانب الأيسر - شارع الزهور', '+9647710004004', '9647710004004', 'rafidain_valley_mosul', 'mosul@rafidain.com', 'inactive', false, '["cash"]', 92.00, 420),
  ('مكتب النجف المالي', 'العراق', 'النجف', 'النجف', 'شارع المدينة - مجمع الجواد', '+9647810005005', '9647810005005', 'najaf_financial_office', 'najaf@kasby-agents.com', 'active', true, '["zain_cash", "cash", "mastercard"]', 97.80, 1100),
  ('صرّاف كربلاء الدولي', 'العراق', 'كربلاء', 'كربلاء', 'شارع قبلة الإمام الحسين عليه السلام', '+9647810006006', '9647810006006', 'karbala_intl_exchange', 'karbala@kasby-agents.com', 'active', true, '["cash", "bank_transfer"]', 98.90, 1560),
  ('مكتب كركوك للصرافة', 'العراق', 'كركوك', 'كركوك', 'شارع أطلس - قرب مجمع كركوك', '+9647710007007', '9647710007007', 'kirkuk_exchange_office', 'kirkuk@kasby-agents.com', 'active', true, '["zain_cash", "cash", "fast_pay"]', 95.50, 670),
  ('الحلة للخدمات المالية', 'العراق', 'بابل', 'الحلة', 'شارع 40 - مقابل مستشفى الحلة الساعي', '+9647810008008', '9647810008008', 'hilla_financial_services', 'hilla@kasby-agents.com', 'active', true, '["cash", "bank_transfer"]', 94.80, 520),
  ('شركة أور للحوالات', 'العراق', 'ذي قار', 'الناصرية', 'شارع الحبوبي - الطابق الثاني', '+9647710009009', '9647710009009', 'ur_exchange_nasiriyah', 'ur@kasby-agents.com', 'active', true, '["zain_cash", "cash"]', 97.00, 890),
  ('السليمانية موني ترانسفير', 'العراق', 'السليمانية', 'السليمانية', 'شارع سالم - مجمع السليمانية ستي', '+9647510010010', '9647510010010', 'sulaymaniyah_transfer', 'suly@kasby-agents.com', 'active', true, '["fast_pay", "cash", "bank_transfer"]', 98.70, 1340)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 9. NOTIFICATIONS & FAQ
-- ============================================================
INSERT INTO notifications (title, message, target) VALUES
  ('تحديث جديد', 'لقد تم إضافة خطط استثمارية جديدة في كركوك والموصل!', 'all'),
  ('مكافأة الإحالة', 'شارك كود الإحالة الخاص بك واحصل على 50 نقطة فوراً.', 'all');

INSERT INTO faqs (question, answer, sort_order) VALUES
  ('هل منصة كاسبي مرخصة؟', 'نعم، المنصة تعمل وفقاً للضوابط المالية وضمانات الوكلاء المعتمدين.', 1),
  ('كيف أحصل على نقاط؟', 'من خلال تسجيل الدخول اليومي، الاستثمار، ودعوة الأصدقاء.', 2);

-- ============================================================
-- 10. ADVERTISEMENTS
-- ============================================================
INSERT INTO ads (title_ar, title_en, description_ar, description_en, image_url, action_url, priority) VALUES
  ('نمو استثماراتك', 'Growth of your investments', 'ابدأ رحلة الاستثمار مع كاسبي اليوم وضاعف أرباحك.', 'Start your investment journey with Kasby today.', 'https://kasby.com/images/slider_growth.png', '/subscription', 10),
  ('أمان تطلعاتك', 'Security of your aspirations', 'نحن نهتم بأمان أموالك وتوفير أفضل الفرص.', 'We care about the security of your funds.', 'https://kasby.com/images/slider_secure.png', '/wallet', 5),
  ('تنوع محفظتك', 'Diversify your portfolio', 'استثمر في الذهب، العقارات، والفضة بضغطة زر.', 'Invest in gold, real estate, and silver.', 'https://kasby.com/images/slider_diversified.png', '/investment_plans', 8)
ON CONFLICT DO NOTHING;

-- ============================================================
-- DONE! Comprehensive Seed with Schema Repair.
-- ============================================================
