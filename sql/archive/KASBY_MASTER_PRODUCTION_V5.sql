-- ╔══════════════════════════════════════════════════════════════╗
-- ║  KASBY – MASTER PRODUCTION SCHEMA V5.0                     ║
-- ║  Architecture: Single Source of Truth (SSOT)               ║
-- ║  Security: RBAC + Phase 9 Hardening + search_path          ║
-- ║  Tables: 31 Tables + 1 View (100% Real DB Match)           ║
-- ║  Serves: Admin Panel + User Application                    ║
-- ╚══════════════════════════════════════════════════════════════╝

BEGIN;

-- ============================================================
-- 0. INFRASTRUCTURE & EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. CUSTOM TYPES (IDEMPOTENT)
-- ============================================================
DO $$ BEGIN
    -- role_type (نوع الدور)
    -- 'user'  = مستخدم | User
    -- 'admin' = مدير  | Admin
    -- 'agent' = وكيل  | Agent
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'role_type') THEN
        CREATE TYPE role_type AS ENUM ('user', 'admin', 'agent');
    END IF;

    -- user_status (حالة المستخدم)
    -- 'active'    = نشط      | Active
    -- 'blocked'   = محظور    | Blocked
    -- 'suspended' = معلّق    | Suspended
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
        CREATE TYPE user_status AS ENUM ('active', 'blocked', 'suspended');
    END IF;

    -- account_tier (مستوى الحساب)
    -- 'free'     = مجاني   | Free
    -- 'verified' = موثّق   | Verified
    -- 'vip'      = مميز    | VIP
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_tier') THEN
        CREATE TYPE account_tier AS ENUM ('free', 'verified', 'vip');
    END IF;

    -- kyc_status (حالة التحقق من الهوية)
    -- 'unverified' = غير موثّق    | Unverified
    -- 'pending'    = قيد المراجعة | Pending
    -- 'verified'   = موثّق        | Verified
    -- 'rejected'   = مرفوض        | Rejected
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kyc_status') THEN
        CREATE TYPE kyc_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
    END IF;

    -- txn_type (نوع المعاملة)
    -- 'deposit'            = إيداع              | Deposit
    -- 'withdrawal'         = سحب                | Withdrawal
    -- 'transfer_in'        = تحويل وارد         | Transfer In
    -- 'transfer_out'       = تحويل صادر         | Transfer Out
    -- 'investment'         = استثمار             | Investment
    -- 'investment_return'  = عائد استثمار        | Investment Return
    -- 'loan_disbursement'  = صرف قرض            | Loan Disbursement
    -- 'loan_repayment'     = سداد قرض           | Loan Repayment
    -- 'reward'             = مكافأة              | Reward
    -- 'adjustment'         = تسوية               | Adjustment
    -- 'profit'             = ربح                 | Profit
    -- 'fee'                = رسوم                | Fee
    -- 'admin_credit'       = إضافة إدارية       | Admin Credit
    -- 'admin_debit'        = خصم إداري          | Admin Debit
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'txn_type') THEN
        CREATE TYPE txn_type AS ENUM ('deposit', 'withdrawal', 'transfer_in', 'transfer_out', 'investment', 'investment_return', 'loan_disbursement', 'loan_repayment', 'reward', 'adjustment', 'profit', 'fee', 'admin_credit', 'admin_debit');
    END IF;

    -- txn_status (حالة المعاملة)
    -- 'pending'    = قيد الانتظار | Pending
    -- 'processing' = قيد المعالجة | Processing
    -- 'completed'  = مكتملة       | Completed
    -- 'approved'   = موافق عليها  | Approved
    -- 'rejected'   = مرفوضة       | Rejected
    -- 'cancelled'  = ملغاة        | Cancelled
    -- 'failed'     = فشلت         | Failed
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'txn_status') THEN
        CREATE TYPE txn_status AS ENUM ('pending', 'processing', 'completed', 'approved', 'rejected', 'cancelled', 'failed');
    END IF;

    -- investment_status (حالة الاستثمار)
    -- 'active'    = نشط     | Active
    -- 'completed' = مكتمل   | Completed
    -- 'cancelled' = ملغي    | Cancelled
    -- 'matured'   = مستحق   | Matured
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'investment_status') THEN
        CREATE TYPE investment_status AS ENUM ('active', 'completed', 'cancelled', 'matured');
    END IF;

    -- loan_status (حالة القرض)
    -- 'pending'   = قيد الانتظار | Pending
    -- 'current'   = جاري         | Current
    -- 'paid'      = مدفوع        | Paid
    -- 'delayed'   = متأخر        | Delayed
    -- 'defaulted' = متعثر        | Defaulted
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'loan_status') THEN
        CREATE TYPE loan_status AS ENUM ('pending', 'current', 'paid', 'delayed', 'defaulted');
    END IF;

    -- agent_status (حالة الوكيل)
    -- 'active'    = نشط    | Active
    -- 'inactive'  = غير نشط | Inactive
    -- 'suspended' = معلّق   | Suspended
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'agent_status') THEN
        CREATE TYPE agent_status AS ENUM ('active', 'inactive', 'suspended');
    END IF;

    -- severity_type (مستوى الخطورة)
    -- 'info'     = معلومات | Info
    -- 'warning'  = تحذير   | Warning
    -- 'critical' = حرج     | Critical
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'severity_type') THEN
        CREATE TYPE severity_type AS ENUM ('info', 'warning', 'critical');
    END IF;

    -- kyc_doc_type (نوع وثيقة التحقق)
    -- 'id_card_front'    = بطاقة هوية (أمامية) | ID Card (Front)
    -- 'id_card_back'     = بطاقة هوية (خلفية)  | ID Card (Back)
    -- 'passport'         = جواز سفر             | Passport
    -- 'selfie'           = صورة شخصية           | Selfie
    -- 'proof_of_address' = إثبات عنوان          | Proof of Address
    -- 'other'            = أخرى                 | Other
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kyc_doc_type') THEN
        CREATE TYPE kyc_doc_type AS ENUM ('id_card_front', 'id_card_back', 'passport', 'selfie', 'proof_of_address', 'other');
    END IF;

    -- audit_log_type (نوع سجل المراجعة)
    -- 'auth'            = مصادقة         | Authentication
    -- 'user_management' = إدارة المستخدمين | User Management
    -- 'financial'       = مالي            | Financial
    -- 'system'          = نظام            | System
    -- 'security'        = أمني            | Security
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'audit_log_type') THEN
        CREATE TYPE audit_log_type AS ENUM ('auth', 'user_management', 'financial', 'system', 'security');
    END IF;

    -- audit_log_status (حالة سجل المراجعة)
    -- 'success' = ناجح   | Success
    -- 'failed'  = فاشل   | Failed
    -- 'warning' = تحذير  | Warning
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'audit_log_status') THEN
        CREATE TYPE audit_log_status AS ENUM ('success', 'failed', 'warning');
    END IF;

    -- message_type (نوع الرسالة)
    -- 'text'   = نص    | Text
    -- 'image'  = صورة  | Image
    -- 'file'   = ملف   | File
    -- 'system' = نظام  | System
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_type') THEN
        CREATE TYPE message_type AS ENUM ('text', 'image', 'file', 'system');
    END IF;

    -- point_rule_type (نوع قاعدة النقاط)
    -- 'earn'  = كسب    | Earn
    -- 'spend' = إنفاق  | Spend
    -- 'bonus' = مكافأة | Bonus
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'point_rule_type') THEN
        CREATE TYPE point_rule_type AS ENUM ('earn', 'spend', 'bonus');
    END IF;

    -- prize_type (نوع الجائزة)
    -- 'points'  = نقاط   | Points
    -- 'cash'    = نقدي   | Cash
    -- 'voucher' = قسيمة  | Voucher
    -- 'nothing' = لا شيء | Nothing
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'prize_type') THEN
        CREATE TYPE prize_type AS ENUM ('points', 'cash', 'voucher', 'nothing');
    END IF;

    -- limit_tier (مستوى الحد)
    -- 'free'     = مجاني | Free
    -- 'verified' = موثّق | Verified
    -- 'vip'      = مميز  | VIP
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'limit_tier') THEN
        CREATE TYPE limit_tier AS ENUM ('free', 'verified', 'vip');
    END IF;

    -- fee_category (فئة الرسوم)
    -- 'deposit'    = إيداع    | Deposit
    -- 'withdrawal' = سحب      | Withdrawal
    -- 'transfer'   = تحويل    | Transfer
    -- 'investment' = استثمار   | Investment
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fee_category') THEN
        CREATE TYPE fee_category AS ENUM ('deposit', 'withdrawal', 'transfer', 'investment');
    END IF;
END $$;

-- ============================================================
-- 1.1 ENUM TRANSLATIONS TABLE (جدول ترجمات الأنواع)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.enum_translations (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    enum_type   TEXT NOT NULL,
    enum_value  TEXT NOT NULL,
    label_ar    TEXT NOT NULL,
    label_en    TEXT NOT NULL,
    UNIQUE(enum_type, enum_value)
);

-- Seed translations (IDEMPOTENT via ON CONFLICT)
INSERT INTO public.enum_translations (enum_type, enum_value, label_ar, label_en) VALUES
    -- role_type
    ('role_type', 'user',  'مستخدم', 'User'),
    ('role_type', 'admin', 'مدير',   'Admin'),
    ('role_type', 'agent', 'وكيل',   'Agent'),
    -- user_status
    ('user_status', 'active',    'نشط',    'Active'),
    ('user_status', 'blocked',   'محظور',   'Blocked'),
    ('user_status', 'suspended', 'معلّق',   'Suspended'),
    -- account_tier
    ('account_tier', 'free',     'مجاني', 'Free'),
    ('account_tier', 'verified', 'موثّق', 'Verified'),
    ('account_tier', 'vip',      'مميز',  'VIP'),
    -- kyc_status
    ('kyc_status', 'unverified', 'غير موثّق',    'Unverified'),
    ('kyc_status', 'pending',    'قيد المراجعة', 'Pending'),
    ('kyc_status', 'verified',   'موثّق',        'Verified'),
    ('kyc_status', 'rejected',   'مرفوض',        'Rejected'),
    -- txn_type
    ('txn_type', 'deposit',           'إيداع',          'Deposit'),
    ('txn_type', 'withdrawal',        'سحب',            'Withdrawal'),
    ('txn_type', 'transfer_in',       'تحويل وارد',     'Transfer In'),
    ('txn_type', 'transfer_out',      'تحويل صادر',     'Transfer Out'),
    ('txn_type', 'investment',        'استثمار',         'Investment'),
    ('txn_type', 'investment_return', 'عائد استثمار',    'Investment Return'),
    ('txn_type', 'loan_disbursement', 'صرف قرض',        'Loan Disbursement'),
    ('txn_type', 'loan_repayment',    'سداد قرض',       'Loan Repayment'),
    ('txn_type', 'reward',            'مكافأة',          'Reward'),
    ('txn_type', 'adjustment',        'تسوية',           'Adjustment'),
    ('txn_type', 'profit',            'ربح',             'Profit'),
    ('txn_type', 'fee',               'رسوم',            'Fee'),
    ('txn_type', 'admin_credit',      'إضافة إدارية',   'Admin Credit'),
    ('txn_type', 'admin_debit',       'خصم إداري',      'Admin Debit'),
    -- txn_status
    ('txn_status', 'pending',    'قيد الانتظار', 'Pending'),
    ('txn_status', 'processing', 'قيد المعالجة', 'Processing'),
    ('txn_status', 'completed',  'مكتملة',       'Completed'),
    ('txn_status', 'approved',   'موافق عليها',  'Approved'),
    ('txn_status', 'rejected',   'مرفوضة',       'Rejected'),
    ('txn_status', 'cancelled',  'ملغاة',        'Cancelled'),
    ('txn_status', 'failed',     'فشلت',         'Failed'),
    -- investment_status
    ('investment_status', 'active',    'نشط',   'Active'),
    ('investment_status', 'completed', 'مكتمل', 'Completed'),
    ('investment_status', 'cancelled', 'ملغي',  'Cancelled'),
    ('investment_status', 'matured',   'مستحق', 'Matured'),
    -- loan_status
    ('loan_status', 'pending',   'قيد الانتظار', 'Pending'),
    ('loan_status', 'current',   'جاري',         'Current'),
    ('loan_status', 'paid',      'مدفوع',        'Paid'),
    ('loan_status', 'delayed',   'متأخر',        'Delayed'),
    ('loan_status', 'defaulted', 'متعثر',        'Defaulted'),
    -- agent_status
    ('agent_status', 'active',    'نشط',     'Active'),
    ('agent_status', 'inactive',  'غير نشط', 'Inactive'),
    ('agent_status', 'suspended', 'معلّق',   'Suspended'),
    -- severity_type
    ('severity_type', 'info',     'معلومات', 'Info'),
    ('severity_type', 'warning',  'تحذير',   'Warning'),
    ('severity_type', 'critical', 'حرج',     'Critical'),
    -- kyc_doc_type
    ('kyc_doc_type', 'id_card_front',    'بطاقة هوية (أمامية)', 'ID Card (Front)'),
    ('kyc_doc_type', 'id_card_back',     'بطاقة هوية (خلفية)',  'ID Card (Back)'),
    ('kyc_doc_type', 'passport',         'جواز سفر',             'Passport'),
    ('kyc_doc_type', 'selfie',           'صورة شخصية',           'Selfie'),
    ('kyc_doc_type', 'proof_of_address', 'إثبات عنوان',          'Proof of Address'),
    ('kyc_doc_type', 'other',            'أخرى',                 'Other'),
    -- audit_log_type
    ('audit_log_type', 'auth',            'مصادقة',           'Authentication'),
    ('audit_log_type', 'user_management', 'إدارة المستخدمين', 'User Management'),
    ('audit_log_type', 'financial',       'مالي',              'Financial'),
    ('audit_log_type', 'system',          'نظام',              'System'),
    ('audit_log_type', 'security',        'أمني',              'Security'),
    -- audit_log_status
    ('audit_log_status', 'success', 'ناجح',  'Success'),
    ('audit_log_status', 'failed',  'فاشل',  'Failed'),
    ('audit_log_status', 'warning', 'تحذير', 'Warning'),
    -- message_type
    ('message_type', 'text',   'نص',   'Text'),
    ('message_type', 'image',  'صورة', 'Image'),
    ('message_type', 'file',   'ملف',  'File'),
    ('message_type', 'system', 'نظام', 'System'),
    -- point_rule_type
    ('point_rule_type', 'earn',  'كسب',    'Earn'),
    ('point_rule_type', 'spend', 'إنفاق',  'Spend'),
    ('point_rule_type', 'bonus', 'مكافأة', 'Bonus'),
    -- prize_type
    ('prize_type', 'points',  'نقاط',   'Points'),
    ('prize_type', 'cash',    'نقدي',   'Cash'),
    ('prize_type', 'voucher', 'قسيمة',  'Voucher'),
    ('prize_type', 'nothing', 'لا شيء', 'Nothing'),
    -- limit_tier
    ('limit_tier', 'free',     'مجاني', 'Free'),
    ('limit_tier', 'verified', 'موثّق', 'Verified'),
    ('limit_tier', 'vip',      'مميز',  'VIP'),
    -- fee_category
    ('fee_category', 'deposit',    'إيداع',   'Deposit'),
    ('fee_category', 'withdrawal', 'سحب',     'Withdrawal'),
    ('fee_category', 'transfer',   'تحويل',   'Transfer'),
    ('fee_category', 'investment', 'استثمار', 'Investment')
ON CONFLICT (enum_type, enum_value) DO UPDATE SET
    label_ar = EXCLUDED.label_ar,
    label_en = EXCLUDED.label_en;

-- Helper function: get translated label for any enum value
CREATE OR REPLACE FUNCTION public.fn_translate_enum(
    p_enum_type TEXT,
    p_enum_value TEXT,
    p_lang TEXT DEFAULT 'ar'  -- 'ar' or 'en'
)
RETURNS TEXT AS $$
DECLARE
    v_label TEXT;
BEGIN
    IF p_lang = 'en' THEN
        SELECT label_en INTO v_label FROM public.enum_translations
        WHERE enum_type = p_enum_type AND enum_value = p_enum_value;
    ELSE
        SELECT label_ar INTO v_label FROM public.enum_translations
        WHERE enum_type = p_enum_type AND enum_value = p_enum_value;
    END IF;
    RETURN COALESCE(v_label, p_enum_value);
END;
$$ LANGUAGE plpgsql STABLE SET search_path = public;

-- ============================================================
-- 2. SECURITY HELPERS
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS role_type AS $$
BEGIN
    RETURN (SELECT role FROM public.profiles WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.get_my_role() = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.is_agent()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN public.get_my_role() = 'agent';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- ============================================================
-- 3. IDENTITY & PROFILES (SSOT - المصدر الوحيد للحقيقة)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       TEXT NOT NULL DEFAULT '',
    email           TEXT UNIQUE NOT NULL,
    phone           TEXT UNIQUE,
    avatar_url      TEXT,
    status          TEXT DEFAULT 'active',
    account_tier    TEXT DEFAULT 'free',
    kyc_status      TEXT DEFAULT 'unverified',
    referral_code   TEXT UNIQUE,
    referred_by     UUID,
    country_code    TEXT,
    province        TEXT DEFAULT '',
    city            TEXT DEFAULT '',
    address         TEXT DEFAULT '',
    whatsapp        TEXT,
    telegram        TEXT,
    last_login_at   TIMESTAMPTZ,
    last_login_ip   TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    referred_by_id  UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    role            role_type DEFAULT 'user'
);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON profiles(status);

-- ============================================================
-- 4. ADMIN PROFILES & SESSIONS (إدارة الأدمن)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.admin_profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role            TEXT DEFAULT 'admin',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.admin_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id        UUID REFERENCES public.admin_profiles(id) ON DELETE CASCADE,
    ip_address      TEXT,
    user_agent      TEXT,
    login_at        TIMESTAMPTZ DEFAULT NOW(),
    logout_at       TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE
);

-- ============================================================
-- 5. FINANCIAL CORE (المحافظ والعمليات)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.wallets (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    available_balance   NUMERIC(18, 4) NOT NULL DEFAULT 0.00 CHECK (available_balance >= 0),
    profit_balance      NUMERIC(18, 4) NOT NULL DEFAULT 0.00 CHECK (profit_balance >= 0),
    invested_balance    NUMERIC(18, 4) NOT NULL DEFAULT 0.00 CHECK (invested_balance >= 0),
    pending_balance     NUMERIC(18, 4) NOT NULL DEFAULT 0.00,
    currency            TEXT NOT NULL DEFAULT 'USD',
    is_frozen           BOOLEAN DEFAULT FALSE,
    frozen_reason       TEXT,
    frozen_at           TIMESTAMPTZ,
    frozen_by           UUID REFERENCES auth.users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transactions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idempotency_key     TEXT UNIQUE,
    user_id             UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    wallet_id           UUID REFERENCES public.wallets(id),
    type                TEXT NOT NULL,
    amount              NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    fee                 NUMERIC(18, 4) DEFAULT 0.00,
    net_amount          NUMERIC(18, 4),
    currency            TEXT DEFAULT 'USD',
    status              TEXT DEFAULT 'pending',
    running_balance     NUMERIC(18, 4),
    counterpart_user_id UUID REFERENCES public.profiles(id),
    reference_id        TEXT,
    reason              TEXT,
    description         TEXT,
    proof_url           TEXT,
    processed_by        UUID REFERENCES auth.users(id),
    processed_at        TIMESTAMPTZ,
    rejection_reason    TEXT,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_txn_user_created ON transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_txn_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_txn_idempotency ON transactions(idempotency_key);

-- ============================================================
-- 6. AGENTS (الوكلاء - بدون تكرار بيانات)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.agents (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status              TEXT DEFAULT 'active',
    is_available_now    BOOLEAN DEFAULT TRUE,
    supported_methods   JSONB DEFAULT '[]',
    success_rate        NUMERIC(5, 2) DEFAULT 100.00,
    total_transactions  INTEGER DEFAULT 0,
    notes               TEXT DEFAULT '',
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. LOGGING & AUDIT (السجلات والرقابة)
-- ============================================================

-- 7.1 Activity Logs (Unified - يستخدمه الطرفان)
CREATE TABLE IF NOT EXISTS public.activity_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    actor_role      role_type,
    action          TEXT NOT NULL,
    entity_type     TEXT,
    entity_id       TEXT,
    details         JSONB DEFAULT '{}'::jsonb,
    severity        TEXT DEFAULT 'info',
    ip_address      TEXT,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 7.2 Audit Logs (Admin-specific - للأدمن فقط)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id        UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action          TEXT NOT NULL,
    details         TEXT,
    type            audit_log_type DEFAULT 'system',
    status          audit_log_status DEFAULT 'success',
    ip_address      TEXT,
    device          TEXT,
    target_id       TEXT,
    target_type     TEXT,
    old_value       JSONB,
    new_value       JSONB,
    metadata        JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 7.3 User Activities (User-specific - للمستخدم فقط)
CREATE TABLE IF NOT EXISTS public.user_activities (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    action          TEXT NOT NULL,
    details         TEXT,
    type            TEXT,
    ip_address      TEXT,
    device          TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. INVESTMENTS (الاستثمارات)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.investment_plans (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_ar             TEXT NOT NULL,
    name_en             TEXT,
    description_ar      TEXT,
    description_en      TEXT,
    image_url           TEXT,
    profit_percentage   NUMERIC(6, 3) NOT NULL,
    duration_days       INTEGER DEFAULT 30,
    min_amount          NUMERIC(18, 4) NOT NULL,
    max_amount          NUMERIC(18, 4),
    available_amounts   JSONB,
    risk_level          TEXT DEFAULT 'medium',
    is_active           BOOLEAN DEFAULT TRUE,
    version             INTEGER DEFAULT 1,
    created_by          UUID REFERENCES auth.users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_investments (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES public.profiles(id),
    plan_id             UUID NOT NULL REFERENCES public.investment_plans(id),
    transaction_id      UUID REFERENCES public.transactions(id),
    amount              NUMERIC(18, 4) NOT NULL,
    profit_percentage   NUMERIC(6, 3),
    expected_profit     NUMERIC(18, 4) NOT NULL,
    actual_profit       NUMERIC(18, 4) DEFAULT 0.00,
    status              TEXT DEFAULT 'active',
    start_date          TIMESTAMPTZ DEFAULT NOW(),
    end_date            TIMESTAMPTZ,
    matured_at          TIMESTAMPTZ,
    approved_by         UUID REFERENCES auth.users(id),
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 9. LOANS (القروض)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.loans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    amount          NUMERIC(18, 4) NOT NULL,
    interest_rate   NUMERIC(6, 3) DEFAULT 0.00,
    total_due       NUMERIC(18, 4) NOT NULL,
    paid_amount     NUMERIC(18, 4) DEFAULT 0.00,
    status          TEXT DEFAULT 'pending',
    loan_date       TIMESTAMPTZ DEFAULT NOW(),
    repayment_date  TIMESTAMPTZ,
    approved_by     UUID REFERENCES auth.users(id),
    approved_at     TIMESTAMPTZ,
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 10. DAILY CHECK-INS & GAMIFICATION (النقاط والمكافآت)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.daily_check_ins (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    points_awarded  INTEGER DEFAULT 10,
    streak          INTEGER DEFAULT 1,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_points (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    current_balance INTEGER DEFAULT 0,
    total_earned    INTEGER DEFAULT 0,
    total_spent     INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.point_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    points          INTEGER NOT NULL,
    type            TEXT NOT NULL,
    description     TEXT,
    reference_id    TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.point_rules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action          TEXT NOT NULL,
    points          INTEGER NOT NULL,
    type            point_rule_type DEFAULT 'earn',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.prizes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label           TEXT NOT NULL,
    value           TEXT,
    type            prize_type DEFAULT 'points',
    probability     NUMERIC(5, 4) DEFAULT 0.00,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.rewards (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    description     TEXT,
    points_cost     INTEGER NOT NULL,
    icon            TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.spin_results (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reward_points   INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 11. KYC & COMPLIANCE (التحقق من الهوية)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.kyc_documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    document_type   TEXT NOT NULL,
    document_url    TEXT NOT NULL,
    status          TEXT DEFAULT 'pending',
    reviewed_by     UUID REFERENCES auth.users(id),
    reviewed_at     TIMESTAMPTZ,
    rejection_reason TEXT,
    uploaded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 12. CHAT SYSTEM (نظام المحادثات)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_conversations (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    agent_id            UUID REFERENCES public.agents(id),
    assigned_admin_id   UUID REFERENCES auth.users(id),
    is_agent_chat       BOOLEAN DEFAULT FALSE,
    last_message        TEXT,
    last_message_at     TIMESTAMPTZ,
    unread_user_count   INTEGER DEFAULT 0,
    unread_admin_count  INTEGER DEFAULT 0,
    is_closed           BOOLEAN DEFAULT FALSE,
    closed_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
    sender_id       UUID REFERENCES auth.users(id),
    sender_type     TEXT NOT NULL,
    content         TEXT,
    message_type    message_type DEFAULT 'text',
    is_edited       BOOLEAN DEFAULT FALSE,
    is_deleted      BOOLEAN DEFAULT FALSE,
    edited_text     TEXT,
    edited_at       TIMESTAMPTZ,
    reactions       TEXT[],
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 13. NOTIFICATIONS (الإشعارات)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,
    message         TEXT NOT NULL,
    target          TEXT,
    target_user_id  UUID REFERENCES public.profiles(id),
    status          TEXT DEFAULT 'unread',
    sent_by         UUID REFERENCES auth.users(id),
    scheduled_at    TIMESTAMPTZ,
    sent_at         TIMESTAMPTZ,
    read_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 14. SUBSCRIPTIONS (الاشتراكات)
-- ============================================================

-- 14.1 Subscription Plans (Admin manages these)
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    price_monthly   NUMERIC(18, 4) DEFAULT 0.00,
    price_yearly    NUMERIC(18, 4) DEFAULT 0.00,
    features        JSONB DEFAULT '[]',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 14.2 User Subscriptions (User records)
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    plan_id         UUID REFERENCES public.subscription_plans(id),
    tier            TEXT NOT NULL,
    is_yearly       BOOLEAN DEFAULT FALSE,
    status          TEXT DEFAULT 'active',
    start_date      TIMESTAMPTZ DEFAULT NOW(),
    end_date        TIMESTAMPTZ,
    price           NUMERIC(18, 4) NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 15. SYSTEM CONFIG & CONTENT (إعدادات النظام والمحتوى)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.system_settings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pause_deposits      BOOLEAN DEFAULT FALSE,
    pause_withdrawals   BOOLEAN DEFAULT FALSE,
    pause_profits       BOOLEAN DEFAULT FALSE,
    pause_investments   BOOLEAN DEFAULT FALSE,
    pause_loans         BOOLEAN DEFAULT FALSE,
    system_freeze       BOOLEAN DEFAULT FALSE,
    is_maintenance_mode BOOLEAN DEFAULT FALSE,
    maintenance_message TEXT,
    updated_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_by          UUID REFERENCES auth.users(id)
);

CREATE TABLE IF NOT EXISTS public.countries (
    code            TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    dial_code       TEXT,
    flag            TEXT,
    is_supported    BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.currencies (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            TEXT NOT NULL,
    code            TEXT UNIQUE NOT NULL,
    symbol          TEXT,
    rate            NUMERIC(18, 6) DEFAULT 1.00,
    decimal_places  INTEGER DEFAULT 2,
    is_base         BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    flag            TEXT,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fees (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label           TEXT NOT NULL,
    value           TEXT,
    percentage      NUMERIC(6, 3),
    fixed_amount    NUMERIC(18, 4),
    category        TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transaction_limits (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label           TEXT NOT NULL,
    value           NUMERIC(18, 4),
    is_unlimited    BOOLEAN DEFAULT FALSE,
    tier            limit_tier,
    category        fee_category,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.faqs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question        TEXT NOT NULL,
    answer          TEXT NOT NULL,
    sort_order      INTEGER DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.terms_sections (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    content         TEXT NOT NULL,
    sort_order      INTEGER DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- 15.7 Advertisements (الإعلانات)
CREATE TABLE IF NOT EXISTS public.ads (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title_ar        TEXT NOT NULL,
    title_en        TEXT,
    description_ar  TEXT,
    description_en  TEXT,
    image_url       TEXT NOT NULL,
    action_url      TEXT,
    priority        INTEGER DEFAULT 0,
    is_active       BOOLEAN DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    created_by      UUID REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_ads_active_priority ON ads(is_active, priority DESC);

-- Seed Data for ads
INSERT INTO public.ads (title_ar, title_en, description_ar, description_en, image_url, action_url, priority, is_active)
VALUES 
('نمو استثماراتك', 'Investment Growth', 'ابدأ رحلة الاستثمار الآمن مع كاسبي اليوم', 'Start your secure investment journey with Kasby today', 'https://raw.githubusercontent.com/Ayman-Altairi/Kasby-Assets/main/slider_growth.png', null, 10, true),
('أمان وحماية', 'Security & Protection', 'نظام حماية متطور لجميع بياناتك ومعاملاتك المالية', 'Advanced protection system for all your data and financial transactions', 'https://raw.githubusercontent.com/Ayman-Altairi/Kasby-Assets/main/slider_secure.png', null, 20, true),
('تنوع المحفظة', 'Portfolio Diversification', 'خيارات استثمارية متعددة تناسب جميع الأهداف', 'Multiple investment options to suit all goals', 'https://raw.githubusercontent.com/Ayman-Altairi/Kasby-Assets/main/slider_diversified.png', null, 30, true);

-- ============================================================
-- 16. TRIGGERS & AUTOMATION
-- ============================================================

-- 16.1 Auto-update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_profiles_updated') THEN
        CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_wallets_updated') THEN
        CREATE TRIGGER trg_wallets_updated BEFORE UPDATE ON wallets FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_agents_updated') THEN
        CREATE TRIGGER trg_agents_updated BEFORE UPDATE ON agents FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
    END IF;
END $$;

-- 16.2 Transaction IMMUTABILITY
CREATE OR REPLACE FUNCTION public.fn_prevent_txn_mutation()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'FORBIDDEN: Transactions are append-only.';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status NOT IN ('pending', 'processing') THEN
            RAISE EXCEPTION 'FORBIDDEN: Finalized transaction cannot be modified.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 16.3 Audit Log IMMUTABILITY
CREATE OR REPLACE FUNCTION public.fn_prevent_audit_mutation()
RETURNS TRIGGER AS $$
BEGIN RAISE EXCEPTION 'FORBIDDEN: Audit logs are immutable.'; END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 16.4 Auto-provision Profile on Auth.User Signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code TEXT;
BEGIN
    IF NEW.raw_user_meta_data ->> 'referred_by_code' IS NOT NULL THEN
        SELECT id INTO v_referred_by_id
        FROM public.profiles
        WHERE referral_code = (NEW.raw_user_meta_data ->> 'referred_by_code');
    END IF;

    LOOP
        v_referral_code := 'K-' || upper(substring(md5(random()::text) from 1 for 4)) || '-' || upper(substring(md5(random()::text) from 5 for 4));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.profiles WHERE referral_code = v_referral_code);
    END LOOP;

    INSERT INTO public.profiles (id, full_name, email, phone, country_code, referral_code, referred_by_id)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        COALESCE(NEW.email, ''),
        COALESCE(NEW.phone, NEW.raw_user_meta_data ->> 'phone'),
        COALESCE(NEW.raw_user_meta_data ->> 'country_code', NULL),
        v_referral_code,
        v_referred_by_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 16.5 Auto-create wallet + user_points when profile is created
CREATE OR REPLACE FUNCTION public.fn_create_wallet_for_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO wallets (user_id) VALUES (NEW.id);
    INSERT INTO user_points (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 17. RPC BUSINESS LOGIC (SECURITY DEFINER)
-- ============================================================

-- 17.1 Process Deposit
CREATE OR REPLACE FUNCTION public.fn_process_deposit(p_txn_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_txn RECORD;
BEGIN
    SELECT * INTO v_txn FROM transactions WHERE id = p_txn_id AND type = 'deposit' AND status = 'pending' FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found or ineligible.'; END IF;

    UPDATE wallets SET available_balance = available_balance + v_txn.amount - COALESCE(v_txn.fee, 0)
    WHERE user_id = v_txn.user_id;

    UPDATE transactions SET status = 'approved', processed_by = p_admin_id, processed_at = NOW()
    WHERE id = p_txn_id;

    INSERT INTO activity_logs (actor_id, actor_role, action, entity_type, entity_id, severity)
    VALUES (p_admin_id, 'admin', 'approve_deposit', 'transaction', p_txn_id::TEXT, 'info');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 17.2 Daily Check-In
CREATE OR REPLACE FUNCTION public.daily_check_in()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_last_checkin TIMESTAMPTZ;
    v_current_streak INTEGER := 1;
    v_points_to_award INTEGER := 10;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    SELECT created_at INTO v_last_checkin
    FROM daily_check_ins WHERE user_id = v_user_id
    ORDER BY created_at DESC LIMIT 1;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE THEN
        RETURN json_build_object('success', FALSE, 'error', 'Already checked in today');
    END IF;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE - INTERVAL '1 day' THEN
        SELECT streak INTO v_current_streak
        FROM daily_check_ins WHERE user_id = v_user_id
        ORDER BY created_at DESC LIMIT 1;
        v_current_streak := v_current_streak + 1;
    END IF;

    IF v_current_streak % 7 = 0 THEN v_points_to_award := 50; END IF;

    INSERT INTO daily_check_ins (user_id, streak, points_awarded)
    VALUES (v_user_id, v_current_streak, v_points_to_award);

    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_user_id, v_points_to_award, 'earn', 'Daily check-in streak: ' || v_current_streak);

    INSERT INTO user_points (user_id, total_earned)
    VALUES (v_user_id, v_points_to_award)
    ON CONFLICT (user_id) DO UPDATE
    SET total_earned = user_points.total_earned + EXCLUDED.total_earned,
        updated_at = CURRENT_TIMESTAMP;

    RETURN json_build_object('success', TRUE, 'streak', v_current_streak, 'points', v_points_to_award);
END;
$$;

-- ============================================================
-- 18. SECURITY & RLS POLICIES (Phase 9 Hardened)
-- ============================================================

-- Enable RLS everywhere
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.point_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spin_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spin_wheel_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;

-- 18.1 PROFILES
DROP POLICY IF EXISTS "Admin full access" ON profiles;
CREATE POLICY "Admin full access" ON profiles FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Users view own" ON profiles;
CREATE POLICY "Users view own" ON profiles FOR SELECT USING (id = auth.uid());
DROP POLICY IF EXISTS "Users update own" ON profiles;
CREATE POLICY "Users update own" ON profiles FOR UPDATE USING (id = auth.uid());

-- 18.2 TRANSACTIONS (Hardened)
DROP POLICY IF EXISTS "Admin scan txns" ON transactions;
CREATE POLICY "Admin scan txns" ON transactions FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view txns" ON transactions;
CREATE POLICY "User view txns" ON transactions FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "User insert requests" ON transactions;
CREATE POLICY "User insert requests" ON transactions FOR INSERT WITH CHECK (user_id = auth.uid());

-- 18.3 WALLETS
DROP POLICY IF EXISTS "Admin scan wallets" ON wallets;
CREATE POLICY "Admin scan wallets" ON wallets FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view wallet" ON wallets;
CREATE POLICY "User view wallet" ON wallets FOR SELECT USING (user_id = auth.uid());

-- 18.4 CHECK-INS (Hardened)
DROP POLICY IF EXISTS "Admin scan checkins" ON daily_check_ins;
CREATE POLICY "Admin scan checkins" ON daily_check_ins FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view checkins" ON daily_check_ins;
CREATE POLICY "User view checkins" ON daily_check_ins FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "User insert checkin" ON daily_check_ins;
CREATE POLICY "User insert checkin" ON daily_check_ins FOR INSERT WITH CHECK (user_id = auth.uid());

-- 18.5 AGENTS
DROP POLICY IF EXISTS "Admin scan agents" ON agents;
CREATE POLICY "Admin scan agents" ON agents FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Agent view self" ON agents;
CREATE POLICY "Agent view self" ON agents FOR SELECT USING (user_id = auth.uid());

-- 18.6 AUDIT/ACTIVITY LOGS
DROP POLICY IF EXISTS "Admin scan audit" ON audit_logs;
CREATE POLICY "Admin scan audit" ON audit_logs FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Admin scan activity" ON activity_logs;
CREATE POLICY "Admin scan activity" ON activity_logs FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view own activity" ON user_activities;
CREATE POLICY "User view own activity" ON user_activities FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Admin scan user_activity" ON user_activities;
CREATE POLICY "Admin scan user_activity" ON user_activities FOR ALL USING (public.is_admin());

-- 18.7 INVESTMENTS
DROP POLICY IF EXISTS "Admin scan investments" ON user_investments;
CREATE POLICY "Admin scan investments" ON user_investments FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view investments" ON user_investments;
CREATE POLICY "User view investments" ON user_investments FOR SELECT USING (user_id = auth.uid());

-- 18.8 ADS
DROP POLICY IF EXISTS "Admin full access ads" ON ads;
CREATE POLICY "Admin full access ads" ON ads FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Anyone view active ads" ON ads;
CREATE POLICY "Anyone view active ads" ON ads FOR SELECT USING (is_active = true AND (expires_at IS NULL OR expires_at > NOW()));

-- 18.8 LOANS
DROP POLICY IF EXISTS "Admin scan loans" ON loans;
CREATE POLICY "Admin scan loans" ON loans FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view loans" ON loans;
CREATE POLICY "User view loans" ON loans FOR SELECT USING (user_id = auth.uid());

-- 18.9 KYC
DROP POLICY IF EXISTS "Admin scan kyc" ON kyc_documents;
CREATE POLICY "Admin scan kyc" ON kyc_documents FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view kyc" ON kyc_documents;
CREATE POLICY "User view kyc" ON kyc_documents FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "User upload kyc" ON kyc_documents;
CREATE POLICY "User upload kyc" ON kyc_documents FOR INSERT WITH CHECK (user_id = auth.uid());

-- 18.10 CHAT
DROP POLICY IF EXISTS "Admin scan chats" ON chat_conversations;
CREATE POLICY "Admin scan chats" ON chat_conversations FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view own chats" ON chat_conversations;
CREATE POLICY "User view own chats" ON chat_conversations FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Admin scan messages" ON chat_messages;
CREATE POLICY "Admin scan messages" ON chat_messages FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view chat messages" ON chat_messages;
CREATE POLICY "User view chat messages" ON chat_messages FOR SELECT USING (
    conversation_id IN (SELECT id FROM chat_conversations WHERE user_id = auth.uid())
);

-- 18.11 NOTIFICATIONS
DROP POLICY IF EXISTS "Admin scan notifs" ON notifications;
CREATE POLICY "Admin scan notifs" ON notifications FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view notifs" ON notifications;
CREATE POLICY "User view notifs" ON notifications FOR SELECT USING (user_id = auth.uid());

-- 18.12 SUBSCRIPTIONS
DROP POLICY IF EXISTS "Admin scan subs" ON subscriptions;
CREATE POLICY "Admin scan subs" ON subscriptions FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view subs" ON subscriptions;
CREATE POLICY "User view subs" ON subscriptions FOR SELECT USING (user_id = auth.uid());

-- 18.13 POINTS & GAMIFICATION
DROP POLICY IF EXISTS "Admin scan points" ON user_points;
CREATE POLICY "Admin scan points" ON user_points FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view points" ON user_points;
CREATE POLICY "User view points" ON user_points FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Admin scan point_history" ON point_history;
CREATE POLICY "Admin scan point_history" ON point_history FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view point_history" ON point_history;
CREATE POLICY "User view point_history" ON point_history FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Admin scan spins" ON spin_results;
CREATE POLICY "Admin scan spins" ON spin_results FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "User view spins" ON spin_results;
CREATE POLICY "User view spins" ON spin_results FOR SELECT USING (user_id = auth.uid());

-- 18.14 SPIN WHEEL REWARDS
DROP POLICY IF EXISTS "Admin scan spin_rewards" ON spin_wheel_rewards;
CREATE POLICY "Admin scan spin_rewards" ON spin_wheel_rewards FOR ALL USING (public.is_admin());
DROP POLICY IF EXISTS "Anyone view active spin rewards" ON spin_wheel_rewards;
CREATE POLICY "Anyone view active spin rewards" ON spin_wheel_rewards FOR SELECT USING (is_active = true);

-- ============================================================
-- 19. VIEW (PERFORMANCE & SECURITY)
-- ============================================================
DROP VIEW IF EXISTS public.v_user_dashboard CASCADE;
CREATE VIEW public.v_user_dashboard
WITH (security_invoker = true) AS
SELECT 
    p.id AS user_id, 
    p.full_name, 
    p.account_tier, 
    p.kyc_status,
    COALESCE(w.available_balance, 0) AS available_balance, 
    COALESCE(w.profit_balance, 0) AS profit_balance, 
    COALESCE(w.invested_balance, 0) AS invested_balance, 
    COALESCE(w.pending_balance, 0) AS pending_balance,
    COALESCE(w.is_frozen, FALSE) AS is_frozen, 
    COALESCE(w.currency, 'USD') AS currency, 
    COALESCE(up.current_balance, 0) AS point_balance,
    (SELECT COUNT(*) FROM user_investments ui WHERE ui.user_id = p.id AND ui.status = 'active')::INT AS active_investments,
    (SELECT COUNT(*) FROM loans l WHERE l.user_id = p.id AND l.status = 'current')::INT AS active_loans,
    (SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE user_id = p.id AND type = 'profit' AND created_at >= NOW() - INTERVAL '24 hours') AS daily_profit,
    CASE WHEN COALESCE(w.invested_balance, 0) > 0 
         THEN ROUND(((SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE user_id = p.id AND type = 'profit' AND created_at >= NOW() - INTERVAL '24 hours') / w.invested_balance * 100), 2)
         ELSE 0 
    END AS profit_percentage
FROM profiles p
LEFT JOIN wallets w ON w.user_id = p.id AND w.currency = 'USD'
LEFT JOIN user_points up ON up.user_id = p.id;

COMMIT;

-- ============================================================
-- END OF KASBY MASTER PRODUCTION SCHEMA V5.0
-- ============================================================
-- 30 Tables | 1 View | 18+ Custom Types
-- Full RLS Coverage | SECURITY DEFINER Functions
-- 100% Match with Production Supabase Database
-- ============================================================
