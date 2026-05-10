-- ╔══════════════════════════════════════════════════════════════╗
-- ║  KASBY – Production-Ready PostgreSQL Schema v3.1           ║
-- ║  Platform: Supabase (auth.users native integration)        ║
-- ║  Date: 2026-02-12 | Audit-Corrected Build                 ║
-- ║  Serves: Kasby User App + Kasby Admin Panel                ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- CUSTOM TYPES (Idempotent creation)
-- ============================================================
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status') THEN
        CREATE TYPE user_status AS ENUM ('active', 'blocked', 'suspended');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_tier') THEN
        CREATE TYPE account_tier AS ENUM ('free', 'verified', 'vip');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kyc_status') THEN
        CREATE TYPE kyc_status AS ENUM ('unverified', 'pending', 'verified', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'txn_type') THEN
        CREATE TYPE txn_type AS ENUM ('deposit', 'withdrawal', 'transfer_in', 'transfer_out', 'investment', 'investment_return', 'loan_disbursement', 'loan_repayment', 'reward', 'adjustment', 'profit', 'fee');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'txn_status') THEN
        CREATE TYPE txn_status AS ENUM ('pending', 'processing', 'completed', 'approved', 'rejected', 'cancelled', 'failed');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'investment_status') THEN
        CREATE TYPE investment_status AS ENUM ('pending', 'active', 'completed', 'cancelled', 'rejected', 'matured');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'loan_status') THEN
        CREATE TYPE loan_status AS ENUM ('pending', 'current', 'paid', 'delayed', 'defaulted');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'agent_status') THEN
        CREATE TYPE agent_status AS ENUM ('active', 'inactive', 'suspended');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'audit_log_type') THEN
        CREATE TYPE audit_log_type AS ENUM ('security', 'financial', 'user_management', 'investment', 'system', 'config');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'audit_log_status') THEN
        CREATE TYPE audit_log_status AS ENUM ('success', 'warning', 'failure');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_status') THEN
        CREATE TYPE notification_status AS ENUM ('sent', 'scheduled', 'failed', 'read');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_type') THEN
        CREATE TYPE message_type AS ENUM ('text', 'image', 'file', 'voice');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'kyc_doc_type') THEN
        CREATE TYPE kyc_doc_type AS ENUM ('id_card_front', 'id_card_back', 'passport', 'selfie', 'proof_of_address', 'other');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fee_category') THEN
        CREATE TYPE fee_category AS ENUM ('deposit', 'withdraw', 'investment', 'transfer', 'loan');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'prize_type') THEN
        CREATE TYPE prize_type AS ENUM ('points', 'cash', 'bonus');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'point_rule_type') THEN
        CREATE TYPE point_rule_type AS ENUM ('earn', 'redeem');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'limit_tier') THEN
        CREATE TYPE limit_tier AS ENUM ('normal', 'vip');
    END IF;
END $$;

-- ============================================================
-- HELPER: Check if current user is admin
-- Reads from auth.users.raw_app_meta_data -> 'is_admin'
-- CANNOT be spoofed by client (unlike current_setting)
-- ============================================================
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN COALESCE(
        (SELECT raw_app_meta_data ->> 'is_admin' FROM auth.users WHERE id = auth.uid())::BOOLEAN,
        FALSE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public;

-- ============================================================
-- SECTION 1: IDENTITY & AUTHENTICATION
-- ============================================================

-- 1.1 PROFILES (Linked to auth.users – CRITICAL)
CREATE TABLE IF NOT EXISTS profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       TEXT NOT NULL DEFAULT '',
    email           TEXT UNIQUE NOT NULL,
    phone           TEXT UNIQUE,
    avatar_url      TEXT,
    status          user_status DEFAULT 'active',
    account_tier    account_tier DEFAULT 'free',
    kyc_status      kyc_status DEFAULT 'unverified',
    country_code    TEXT,
    province        TEXT DEFAULT '',
    city            TEXT DEFAULT '',
    address         TEXT DEFAULT '',
    whatsapp        TEXT DEFAULT '',
    telegram        TEXT DEFAULT '',
    referral_code   TEXT UNIQUE,
    referred_by_id  UUID REFERENCES profiles(id) ON DELETE SET NULL,
    last_login_at   TIMESTAMPTZ,
    last_login_ip   TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referral_code TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS referred_by_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT UNIQUE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS country_code TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status user_status DEFAULT 'active';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS account_tier account_tier DEFAULT 'free';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS kyc_status kyc_status DEFAULT 'unverified';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS province TEXT DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS city TEXT DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS address TEXT DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS whatsapp TEXT DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS telegram TEXT DEFAULT '';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_profiles_status ON profiles(status);
CREATE INDEX IF NOT EXISTS idx_profiles_kyc ON profiles(kyc_status);
CREATE INDEX IF NOT EXISTS idx_profiles_country ON profiles(country_code);

-- 1.2 ADMIN PROFILES (Extension of auth.users with is_admin=true)
CREATE TABLE IF NOT EXISTS admin_profiles (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       TEXT NOT NULL,
    role            TEXT DEFAULT 'viewer' CHECK (role IN ('superadmin', 'admin', 'viewer')),
    is_active       BOOLEAN DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    last_login_ip   TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 1.3 ADMIN SESSIONS
CREATE TABLE IF NOT EXISTS admin_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id        UUID NOT NULL REFERENCES admin_profiles(id) ON DELETE CASCADE,
    ip_address      TEXT NOT NULL,
    user_agent      TEXT,
    login_at        TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    logout_at       TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin ON admin_sessions(admin_id);

-- 1.4 COUNTRIES
CREATE TABLE IF NOT EXISTS countries (
    code            TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    dial_code       TEXT NOT NULL,
    flag            TEXT DEFAULT '',
    is_supported    BOOLEAN DEFAULT TRUE
);

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name = 'fk_profiles_country') THEN
        ALTER TABLE profiles ADD CONSTRAINT fk_profiles_country
            FOREIGN KEY (country_code) REFERENCES countries(code) ON DELETE SET NULL;
    END IF;
END $$;

-- 1.5 KYC DOCUMENTS
CREATE TABLE IF NOT EXISTS kyc_documents (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    document_type   kyc_doc_type NOT NULL,
    document_url    TEXT NOT NULL,
    status          kyc_status DEFAULT 'pending',
    reviewed_by     UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    reviewed_at     TIMESTAMPTZ,
    rejection_reason TEXT,
    uploaded_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_kyc_user ON kyc_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_status ON kyc_documents(status);

-- ============================================================
-- SECTION 2: FINANCIAL CORE
-- ============================================================

-- 2.1 WALLETS
CREATE TABLE IF NOT EXISTS wallets (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    available_balance   NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (available_balance >= 0),
    profit_balance      NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (profit_balance >= 0),
    invested_balance    NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (invested_balance >= 0),
    pending_balance     NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (pending_balance >= 0),
    currency            TEXT NOT NULL DEFAULT 'USD',
    is_frozen           BOOLEAN DEFAULT FALSE,
    frozen_reason       TEXT,
    frozen_at           TIMESTAMPTZ,
    frozen_by           UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_wallets_user ON wallets(user_id);

-- 2.2 TRANSACTIONS (Immutable Ledger)
CREATE TABLE IF NOT EXISTS transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idempotency_key TEXT UNIQUE,
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    wallet_id       UUID NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
    type            txn_type NOT NULL,
    amount          NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    fee             NUMERIC(18, 4) DEFAULT 0.0000 CHECK (fee >= 0),
    net_amount      NUMERIC(18, 4) GENERATED ALWAYS AS (amount - fee) STORED,
    currency        TEXT NOT NULL DEFAULT 'USD',
    status          txn_status DEFAULT 'pending',
    running_balance NUMERIC(18, 4),
    counterpart_user_id UUID REFERENCES profiles(id) ON DELETE RESTRICT,
    reference_id    TEXT,
    reason          TEXT,
    description     TEXT,
    proof_url       TEXT,
    processed_by    UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    processed_at    TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_txn_user ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_txn_wallet ON transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_txn_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_txn_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_txn_created ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_txn_counterpart ON transactions(counterpart_user_id) WHERE counterpart_user_id IS NOT NULL;

-- ============================================================
-- SECTION 3: INVESTMENT & LOANS
-- ============================================================

CREATE TABLE IF NOT EXISTS investment_plans (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name_ar             TEXT NOT NULL,
    name_en             TEXT,
    description_ar      TEXT DEFAULT '',
    description_en      TEXT,
    image_url           TEXT,
    profit_percentage   NUMERIC(6, 3) NOT NULL CHECK (profit_percentage >= 0),
    duration_days       INTEGER,
    min_amount          NUMERIC(18, 4) NOT NULL CHECK (min_amount > 0),
    max_amount          NUMERIC(18, 4) CHECK (max_amount >= min_amount),
    available_amounts   JSONB,
    risk_level          TEXT DEFAULT 'medium' CHECK (risk_level IN ('low', 'medium', 'high')),
    is_active           BOOLEAN DEFAULT TRUE,
    version             INTEGER DEFAULT 1,
    created_by          UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_investments (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    plan_id             UUID NOT NULL REFERENCES investment_plans(id) ON DELETE RESTRICT,
    transaction_id      UUID REFERENCES transactions(id) ON DELETE RESTRICT,
    amount              NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    profit_percentage   NUMERIC(6, 3) NOT NULL,
    expected_profit     NUMERIC(18, 4) NOT NULL DEFAULT 0.0000,
    actual_profit       NUMERIC(18, 4),
    status              investment_status DEFAULT 'active',
    start_date          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    end_date            TIMESTAMPTZ,
    matured_at          TIMESTAMPTZ,
    approved_by         UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_inv_user ON user_investments(user_id);
CREATE INDEX IF NOT EXISTS idx_inv_plan ON user_investments(plan_id);
CREATE INDEX IF NOT EXISTS idx_inv_status ON user_investments(status);

CREATE TABLE IF NOT EXISTS loans (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    amount              NUMERIC(18, 4) NOT NULL CHECK (amount > 0),
    interest_rate       NUMERIC(6, 3) DEFAULT 0.000,
    total_due           NUMERIC(18, 4) GENERATED ALWAYS AS (amount + (amount * interest_rate / 100)) STORED,
    paid_amount         NUMERIC(18, 4) DEFAULT 0.0000 CHECK (paid_amount >= 0),
    status              loan_status DEFAULT 'pending',
    loan_date           TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    repayment_date      TIMESTAMPTZ NOT NULL,
    approved_by         UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    approved_at         TIMESTAMPTZ,
    paid_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_loans_user ON loans(user_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_loans_repay ON loans(repayment_date) WHERE status IN ('current', 'delayed');

-- ============================================================
-- SECTION 4: AGENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS agents (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID UNIQUE REFERENCES profiles(id) ON DELETE SET NULL,
    name                TEXT NOT NULL,
    country             TEXT DEFAULT '',
    province            TEXT DEFAULT '',
    city                TEXT DEFAULT '',
    address             TEXT DEFAULT '',
    phone               TEXT NOT NULL,
    whatsapp            TEXT DEFAULT '',
    telegram            TEXT DEFAULT '',
    email               TEXT DEFAULT '',
    status              agent_status DEFAULT 'active',
    is_available_now    BOOLEAN DEFAULT FALSE,
    supported_methods   JSONB DEFAULT '[]',
    success_rate        NUMERIC(5, 2) DEFAULT 0.00 CHECK (success_rate BETWEEN 0 AND 100),
    total_transactions  INTEGER DEFAULT 0 CHECK (total_transactions >= 0),
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_agents_status ON agents(status);

-- ============================================================
-- SECTION 5: AUDIT & COMPLIANCE
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    admin_id        UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    action          TEXT NOT NULL,
    details         TEXT DEFAULT '',
    type            audit_log_type DEFAULT 'system',
    status          audit_log_status DEFAULT 'success',
    ip_address      TEXT,
    device          TEXT,
    target_id       TEXT,
    target_type     TEXT,
    old_value       JSONB,
    new_value       JSONB,
    metadata        JSONB,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_audit_type ON audit_logs(type);
CREATE INDEX IF NOT EXISTS idx_audit_admin ON audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);

CREATE TABLE IF NOT EXISTS user_activities (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    action          TEXT NOT NULL,
    details         TEXT DEFAULT '',
    type            TEXT DEFAULT 'system' CHECK (type IN ('security', 'transaction', 'system', 'support')),
    ip_address      TEXT,
    device          TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_activities_user ON user_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_created ON user_activities(created_at DESC);

-- ============================================================
-- SECTION 6: COMMUNICATION
-- ============================================================

CREATE TABLE IF NOT EXISTS chat_conversations (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    agent_id            UUID REFERENCES agents(id) ON DELETE SET NULL,
    assigned_admin_id   UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    is_agent_chat       BOOLEAN DEFAULT FALSE,
    last_message        TEXT DEFAULT '',
    last_message_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    unread_user_count   INTEGER DEFAULT 0 CHECK (unread_user_count >= 0),
    unread_admin_count  INTEGER DEFAULT 0 CHECK (unread_admin_count >= 0),
    is_closed           BOOLEAN DEFAULT FALSE,
    closed_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_conv_user ON chat_conversations(user_id);

CREATE TABLE IF NOT EXISTS chat_messages (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id     UUID NOT NULL REFERENCES chat_conversations(id) ON DELETE RESTRICT,
    sender_id           UUID NOT NULL,
    sender_type         TEXT NOT NULL CHECK (sender_type IN ('user', 'admin', 'agent', 'system')),
    content             TEXT NOT NULL,
    message_type        message_type DEFAULT 'text',
    is_edited           BOOLEAN DEFAULT FALSE,
    is_deleted          BOOLEAN DEFAULT FALSE,
    edited_text         TEXT,
    edited_at           TIMESTAMPTZ,
    reactions           TEXT[] DEFAULT '{}',
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_msg_conv ON chat_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_msg_created ON chat_messages(created_at DESC);

CREATE TABLE IF NOT EXISTS notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    message         TEXT NOT NULL,
    target          TEXT DEFAULT 'all',
    target_user_id  UUID REFERENCES profiles(id) ON DELETE CASCADE,
    status          notification_status DEFAULT 'sent',
    sent_by         UUID REFERENCES admin_profiles(id) ON DELETE SET NULL,
    scheduled_at    TIMESTAMPTZ,
    sent_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    read_at         TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_notif_target ON notifications(target_user_id) WHERE target_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notif_status ON notifications(status);

-- ============================================================
-- SECTION 7: GAMIFICATION
-- ============================================================

CREATE TABLE IF NOT EXISTS rewards (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           TEXT NOT NULL,
    description     TEXT DEFAULT '',
    points_cost     INTEGER NOT NULL DEFAULT 0 CHECK (points_cost >= 0),
    icon            TEXT DEFAULT '',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS prizes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label           TEXT NOT NULL,
    value           TEXT NOT NULL,
    type            prize_type DEFAULT 'points',
    probability     NUMERIC(6, 4) NOT NULL CHECK (probability BETWEEN 0 AND 1),
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS point_rules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action          TEXT NOT NULL,
    points          INTEGER NOT NULL CHECK (points > 0),
    type            point_rule_type DEFAULT 'earn',
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_points (
    user_id         UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE RESTRICT,
    total_earned    INTEGER DEFAULT 0 CHECK (total_earned >= 0),
    total_spent     INTEGER DEFAULT 0 CHECK (total_spent >= 0),
    current_balance INTEGER GENERATED ALWAYS AS (total_earned - total_spent) STORED,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS point_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    rule_id         UUID REFERENCES point_rules(id) ON DELETE SET NULL,
    points          INTEGER NOT NULL,
    type            point_rule_type NOT NULL,
    description     TEXT DEFAULT '',
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_point_hist_user ON point_history(user_id);

CREATE TABLE IF NOT EXISTS daily_check_ins (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    streak          INTEGER NOT NULL DEFAULT 1 CHECK (streak > 0),
    points_awarded  INTEGER NOT NULL CHECK (points_awarded >= 0),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_checkin_user_date ON daily_check_ins(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS spin_results (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reward_points   INTEGER NOT NULL CHECK (reward_points >= 0),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_spin_user ON spin_results(user_id);

CREATE TABLE IF NOT EXISTS subscriptions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tier                account_tier NOT NULL,
    status              TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'cancelled')),
    is_yearly           BOOLEAN DEFAULT FALSE,
    amount              NUMERIC(18, 4) NOT NULL CHECK (amount >= 0),
    start_date          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    end_date            TIMESTAMPTZ NOT NULL,
    payment_transaction_id UUID REFERENCES transactions(id),
    auto_renew          BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_sub_user ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_sub_status ON subscriptions(status);

-- ============================================================
-- SECTION 8: SYSTEM CONFIGURATION
-- ============================================================

CREATE TABLE IF NOT EXISTS system_settings (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pause_deposits        BOOLEAN DEFAULT FALSE,
    pause_withdrawals     BOOLEAN DEFAULT FALSE,
    pause_profits         BOOLEAN DEFAULT FALSE,
    pause_investments     BOOLEAN DEFAULT FALSE,
    pause_loans           BOOLEAN DEFAULT FALSE,
    system_freeze         BOOLEAN DEFAULT FALSE,
    is_maintenance_mode   BOOLEAN DEFAULT FALSE,
    maintenance_message   TEXT DEFAULT '',
    updated_at            TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by            UUID REFERENCES admin_profiles(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS faqs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question TEXT NOT NULL, answer TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0, is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS terms_sections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL, content TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0, is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label TEXT NOT NULL, value TEXT NOT NULL,
    percentage NUMERIC(6,3), fixed_amount NUMERIC(18,4),
    category fee_category NOT NULL, is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS currencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL, code TEXT UNIQUE NOT NULL, symbol TEXT DEFAULT '',
    rate NUMERIC(18, 8) NOT NULL, decimal_places INTEGER DEFAULT 2,
    is_base BOOLEAN DEFAULT FALSE, is_active BOOLEAN DEFAULT TRUE,
    flag TEXT DEFAULT '', updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_currencies_base ON currencies(is_base) WHERE is_base = TRUE;

CREATE TABLE IF NOT EXISTS transaction_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    label TEXT NOT NULL, value NUMERIC(18,4),
    is_unlimited BOOLEAN DEFAULT FALSE, tier limit_tier NOT NULL,
    category fee_category, created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 8.3 ADVERTISEMENTS
CREATE TABLE IF NOT EXISTS ads (
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
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ads_active_priority ON ads(is_active, priority DESC);

-- ============================================================
-- SECTION 9: TRIGGERS
-- ============================================================

-- 9.1 Auto-update updated_at
DROP FUNCTION IF EXISTS fn_update_timestamp() CASCADE;
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_ts ON profiles;
CREATE TRIGGER trg_profiles_ts       BEFORE UPDATE ON profiles         FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_admins_ts ON admin_profiles;
CREATE TRIGGER trg_admins_ts         BEFORE UPDATE ON admin_profiles   FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_wallets_ts ON wallets;
CREATE TRIGGER trg_wallets_ts        BEFORE UPDATE ON wallets          FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_agents_ts ON agents;
CREATE TRIGGER trg_agents_ts         BEFORE UPDATE ON agents           FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_inv_plans_ts ON investment_plans;
CREATE TRIGGER trg_inv_plans_ts      BEFORE UPDATE ON investment_plans FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_terms_ts ON terms_sections;
CREATE TRIGGER trg_terms_ts          BEFORE UPDATE ON terms_sections   FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_currencies_ts ON currencies;
CREATE TRIGGER trg_currencies_ts     BEFORE UPDATE ON currencies       FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_points_ts ON user_points;
CREATE TRIGGER trg_points_ts         BEFORE UPDATE ON user_points      FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_settings_ts ON system_settings;
CREATE TRIGGER trg_settings_ts       BEFORE UPDATE ON system_settings  FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();
DROP TRIGGER IF EXISTS trg_ads_ts ON ads;
CREATE TRIGGER trg_ads_ts            BEFORE UPDATE ON ads              FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- 9.2 Transaction IMMUTABILITY
DROP FUNCTION IF EXISTS fn_prevent_txn_mutation() CASCADE;
CREATE OR REPLACE FUNCTION fn_prevent_txn_mutation()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'FORBIDDEN: Transactions are append-only. Cannot delete.';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.status NOT IN ('pending', 'processing') THEN
            RAISE EXCEPTION 'FORBIDDEN: Finalized transaction cannot be modified.';
        END IF;
        IF OLD.amount != NEW.amount OR OLD.type != NEW.type OR OLD.user_id != NEW.user_id THEN
            RAISE EXCEPTION 'FORBIDDEN: amount, type, user_id are immutable.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_txn_immutable ON transactions;
CREATE TRIGGER trg_txn_immutable
    BEFORE UPDATE OR DELETE ON transactions
    FOR EACH ROW EXECUTE FUNCTION fn_prevent_txn_mutation();

-- 9.3 Audit Log IMMUTABILITY
DROP FUNCTION IF EXISTS fn_prevent_audit_mutation() CASCADE;
CREATE OR REPLACE FUNCTION fn_prevent_audit_mutation()
RETURNS TRIGGER AS $$
BEGIN RAISE EXCEPTION 'FORBIDDEN: Audit logs are immutable.'; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_immutable ON audit_logs;
CREATE TRIGGER trg_audit_immutable
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION fn_prevent_audit_mutation();

-- 9.4 Auto-create profile + wallet on auth.users signup
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_referred_by_id UUID := NULL;
    v_referral_code TEXT;
BEGIN
    -- Resolve referred_by_code to UUID if provided
    IF NEW.raw_user_meta_data ->> 'referred_by_code' IS NOT NULL THEN
        SELECT id INTO v_referred_by_id
        FROM public.profiles
        WHERE referral_code = (NEW.raw_user_meta_data ->> 'referred_by_code');
    END IF;

    -- Generate a unique referral code for the new user
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
    -- Wallet + points auto-created by trg_auto_wallet below
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 9.5 Auto-create wallet + user_points when profile is created
DROP FUNCTION IF EXISTS fn_create_wallet_for_user() CASCADE;
CREATE OR REPLACE FUNCTION fn_create_wallet_for_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO wallets (user_id) VALUES (NEW.id);
    INSERT INTO user_points (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS trg_auto_wallet ON profiles;
CREATE TRIGGER trg_auto_wallet
    AFTER INSERT ON profiles
    FOR EACH ROW EXECUTE FUNCTION fn_create_wallet_for_user();

-- ============================================================
-- SECTION 10: RPC FUNCTIONS (SECURITY DEFINER – bypass RLS)
-- These are the ONLY way to modify wallet balances.
-- ============================================================

-- 10.1 PROCESS DEPOSIT
DROP FUNCTION IF EXISTS fn_process_deposit(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION fn_process_deposit(p_txn_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_wallet_id UUID; v_amount NUMERIC(18,4); v_fee NUMERIC(18,4);
    v_net NUMERIC(18,4); v_new_bal NUMERIC(18,4); v_frozen BOOLEAN;
BEGIN
    SELECT wallet_id, amount, fee INTO v_wallet_id, v_amount, v_fee
    FROM transactions WHERE id = p_txn_id AND type = 'deposit' AND status = 'pending';
    IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found or ineligible.'; END IF;

    v_net := v_amount - v_fee;

    SELECT is_frozen INTO v_frozen FROM wallets WHERE id = v_wallet_id FOR UPDATE;
    IF v_frozen THEN RAISE EXCEPTION 'Wallet is frozen.'; END IF;
    IF EXISTS (SELECT 1 FROM system_settings WHERE pause_deposits = TRUE LIMIT 1) THEN
        RAISE EXCEPTION 'Deposits paused.'; END IF;

    UPDATE wallets SET available_balance = available_balance + v_net WHERE id = v_wallet_id;
    SELECT available_balance INTO v_new_bal FROM wallets WHERE id = v_wallet_id;

    UPDATE transactions SET status = 'completed', running_balance = v_new_bal,
        processed_by = p_admin_id, processed_at = CURRENT_TIMESTAMP WHERE id = p_txn_id;

    INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
    VALUES (p_admin_id, 'approve_deposit', 'Amount: ' || v_amount, 'financial', 'success', p_txn_id::TEXT, 'transaction');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10.2 PROCESS WITHDRAWAL
DROP FUNCTION IF EXISTS fn_process_withdrawal(UUID, UUID) CASCADE;
CREATE OR REPLACE FUNCTION fn_process_withdrawal(p_txn_id UUID, p_admin_id UUID)
RETURNS VOID AS $$
DECLARE
    v_wallet_id UUID; v_amount NUMERIC(18,4); v_available NUMERIC(18,4);
    v_new_bal NUMERIC(18,4); v_frozen BOOLEAN;
BEGIN
    SELECT wallet_id, amount INTO v_wallet_id, v_amount
    FROM transactions WHERE id = p_txn_id AND type = 'withdrawal' AND status = 'pending';
    IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not found or ineligible.'; END IF;

    SELECT is_frozen, available_balance INTO v_frozen, v_available
    FROM wallets WHERE id = v_wallet_id FOR UPDATE;
    IF v_frozen THEN RAISE EXCEPTION 'Wallet is frozen.'; END IF;
    IF EXISTS (SELECT 1 FROM system_settings WHERE pause_withdrawals = TRUE LIMIT 1) THEN
        RAISE EXCEPTION 'Withdrawals paused.'; END IF;
    IF v_available < v_amount THEN
        RAISE EXCEPTION 'Insufficient balance. Available: %, Requested: %', v_available, v_amount; END IF;

    UPDATE wallets SET available_balance = available_balance - v_amount WHERE id = v_wallet_id;
    SELECT available_balance INTO v_new_bal FROM wallets WHERE id = v_wallet_id;

    UPDATE transactions SET status = 'completed', running_balance = v_new_bal,
        processed_by = p_admin_id, processed_at = CURRENT_TIMESTAMP WHERE id = p_txn_id;

    INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
    VALUES (p_admin_id, 'approve_withdrawal', 'Amount: ' || v_amount, 'financial', 'success', p_txn_id::TEXT, 'transaction');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10.3 REJECT TRANSACTION
DROP FUNCTION IF EXISTS fn_reject_transaction(UUID, UUID, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION fn_reject_transaction(p_txn_id UUID, p_admin_id UUID, p_reason TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE transactions SET status = 'rejected', rejection_reason = p_reason,
        processed_by = p_admin_id, processed_at = CURRENT_TIMESTAMP
    WHERE id = p_txn_id AND status IN ('pending', 'processing');
    IF NOT FOUND THEN RAISE EXCEPTION 'Transaction not rejectable.'; END IF;

    INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
    VALUES (p_admin_id, 'reject_transaction', p_reason, 'financial', 'warning', p_txn_id::TEXT, 'transaction');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10.4 P2P TRANSFER (Deadlock-safe: locks wallets in UUID order)
DROP FUNCTION IF EXISTS fn_transfer(UUID, UUID, NUMERIC, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION fn_transfer(
    p_sender_id UUID, p_receiver_id UUID, p_amount NUMERIC(18,4), p_idempotency_key TEXT
) RETURNS UUID AS $$
DECLARE
    v_sw UUID; v_rw UUID; v_sb NUMERIC(18,4);
    v_txn_out UUID; v_txn_in UUID;
    v_frozen_s BOOLEAN; v_frozen_r BOOLEAN;
BEGIN
    IF p_sender_id = p_receiver_id THEN RAISE EXCEPTION 'Cannot transfer to self.'; END IF;
    IF p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be positive.'; END IF;
    IF EXISTS (SELECT 1 FROM system_settings WHERE system_freeze LIMIT 1) THEN
        RAISE EXCEPTION 'System frozen.'; END IF;

    -- Lock wallets in UUID order to prevent deadlocks
    IF p_sender_id < p_receiver_id THEN
        SELECT id, available_balance, is_frozen INTO v_sw, v_sb, v_frozen_s
        FROM wallets WHERE user_id = p_sender_id FOR UPDATE;
        SELECT id, is_frozen INTO v_rw, v_frozen_r
        FROM wallets WHERE user_id = p_receiver_id FOR UPDATE;
    ELSE
        SELECT id, is_frozen INTO v_rw, v_frozen_r
        FROM wallets WHERE user_id = p_receiver_id FOR UPDATE;
        SELECT id, available_balance, is_frozen INTO v_sw, v_sb, v_frozen_s
        FROM wallets WHERE user_id = p_sender_id FOR UPDATE;
    END IF;

    IF v_frozen_s THEN RAISE EXCEPTION 'Sender wallet frozen.'; END IF;
    IF v_frozen_r THEN RAISE EXCEPTION 'Receiver wallet frozen.'; END IF;
    IF v_sb < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance. Available: %, Requested: %', v_sb, p_amount; END IF;

    UPDATE wallets SET available_balance = available_balance - p_amount WHERE id = v_sw;
    v_txn_out := uuid_generate_v4();
    INSERT INTO transactions (id, idempotency_key, user_id, wallet_id, type, amount, currency, status, counterpart_user_id, running_balance)
    VALUES (v_txn_out, p_idempotency_key||'_out', p_sender_id, v_sw, 'transfer_out', p_amount, 'USD', 'completed', p_receiver_id,
            (SELECT available_balance FROM wallets WHERE id = v_sw));

    UPDATE wallets SET available_balance = available_balance + p_amount WHERE id = v_rw;
    v_txn_in := uuid_generate_v4();
    INSERT INTO transactions (id, idempotency_key, user_id, wallet_id, type, amount, currency, status, counterpart_user_id, running_balance)
    VALUES (v_txn_in, p_idempotency_key||'_in', p_receiver_id, v_rw, 'transfer_in', p_amount, 'USD', 'completed', p_sender_id,
            (SELECT available_balance FROM wallets WHERE id = v_rw));

    RETURN v_txn_out;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10.5 CREATE INVESTMENT
DROP FUNCTION IF EXISTS fn_create_investment(UUID, UUID, NUMERIC, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION fn_create_investment(
    p_user_id UUID, p_plan_id UUID, p_amount NUMERIC(18,4), p_idempotency_key TEXT
) RETURNS UUID AS $$
DECLARE
    v_wid UUID; v_bal NUMERIC(18,4); v_pct NUMERIC(6,3);
    v_min NUMERIC(18,4); v_max NUMERIC(18,4); v_active BOOLEAN;
    v_dur INTEGER; v_txn UUID; v_inv UUID; v_frozen BOOLEAN;
BEGIN
    SELECT profit_percentage, min_amount, max_amount, is_active, duration_days
    INTO v_pct, v_min, v_max, v_active, v_dur
    FROM investment_plans WHERE id = p_plan_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Plan not found.'; END IF;
    IF NOT v_active THEN RAISE EXCEPTION 'Plan inactive.'; END IF;
    IF p_amount < v_min THEN RAISE EXCEPTION 'Below minimum: %', v_min; END IF;
    IF v_max IS NOT NULL AND p_amount > v_max THEN RAISE EXCEPTION 'Exceeds maximum: %', v_max; END IF;
    IF EXISTS (SELECT 1 FROM system_settings WHERE pause_investments = TRUE LIMIT 1) THEN
        RAISE EXCEPTION 'Investments paused.'; END IF;

    SELECT id, available_balance, is_frozen INTO v_wid, v_bal, v_frozen
    FROM wallets WHERE user_id = p_user_id FOR UPDATE;
    IF v_frozen THEN RAISE EXCEPTION 'Wallet frozen.'; END IF;
    IF v_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient balance: %, Requested: %', v_bal, p_amount; END IF;

    UPDATE wallets SET available_balance = available_balance - p_amount,
        invested_balance = invested_balance + p_amount WHERE id = v_wid;

    v_txn := uuid_generate_v4();
    INSERT INTO transactions (id, idempotency_key, user_id, wallet_id, type, amount, currency, status, running_balance)
    VALUES (v_txn, p_idempotency_key, p_user_id, v_wid, 'investment', p_amount, 'USD', 'completed',
            (SELECT available_balance FROM wallets WHERE id = v_wid));

    v_inv := uuid_generate_v4();
    INSERT INTO user_investments (id, user_id, plan_id, transaction_id, amount, profit_percentage, expected_profit, start_date, end_date)
    VALUES (v_inv, p_user_id, p_plan_id, v_txn, p_amount, v_pct, p_amount * v_pct / 100,
            CURRENT_TIMESTAMP,
            CASE WHEN v_dur IS NOT NULL THEN CURRENT_TIMESTAMP + (v_dur || ' days')::INTERVAL ELSE NULL END);

    RETURN v_inv;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 10.6 CREDIT PROFIT (Admin credits profit to a matured investment)
DROP FUNCTION IF EXISTS fn_credit_profit(UUID, UUID, NUMERIC) CASCADE;
CREATE OR REPLACE FUNCTION fn_credit_profit(
    p_investment_id UUID, p_admin_id UUID, p_profit_amount NUMERIC(18,4)
) RETURNS VOID AS $$
DECLARE
    v_user_id UUID; v_wid UUID; v_inv_amount NUMERIC(18,4);
    v_inv_status investment_status; v_new_bal NUMERIC(18,4);
BEGIN
    SELECT user_id, amount, status INTO v_user_id, v_inv_amount, v_inv_status
    FROM user_investments WHERE id = p_investment_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Investment not found.'; END IF;
    IF v_inv_status != 'active' THEN RAISE EXCEPTION 'Investment not active. Status: %', v_inv_status; END IF;
    IF EXISTS (SELECT 1 FROM system_settings WHERE pause_profits = TRUE LIMIT 1) THEN
        RAISE EXCEPTION 'Profits paused.'; END IF;

    SELECT id INTO v_wid FROM wallets WHERE user_id = v_user_id FOR UPDATE;

    -- Return invested amount to available + add profit
    UPDATE wallets SET
        available_balance = available_balance + v_inv_amount,
        profit_balance = profit_balance + p_profit_amount,
        invested_balance = invested_balance - v_inv_amount
    WHERE id = v_wid;

    SELECT available_balance INTO v_new_bal FROM wallets WHERE id = v_wid;

    -- Record investment return transaction
    INSERT INTO transactions (user_id, wallet_id, type, amount, currency, status, running_balance, processed_by, processed_at, description)
    VALUES (v_user_id, v_wid, 'investment_return', v_inv_amount, 'USD', 'completed', v_new_bal, p_admin_id, CURRENT_TIMESTAMP,
            'Return of principal');

    -- Record profit transaction
    IF p_profit_amount > 0 THEN
        INSERT INTO transactions (user_id, wallet_id, type, amount, currency, status, running_balance, processed_by, processed_at, description)
        VALUES (v_user_id, v_wid, 'profit', p_profit_amount, 'USD', 'completed',
                v_new_bal + p_profit_amount, p_admin_id, CURRENT_TIMESTAMP, 'Profit from investment');
        UPDATE wallets SET available_balance = available_balance + p_profit_amount WHERE id = v_wid;
    END IF;

    -- Mark investment as matured
    UPDATE user_investments SET status = 'matured', actual_profit = p_profit_amount,
        matured_at = CURRENT_TIMESTAMP WHERE id = p_investment_id;

    INSERT INTO audit_logs (admin_id, action, details, type, status, target_id, target_type)
    VALUES (p_admin_id, 'credit_profit', 'Profit: '||p_profit_amount||' on investment '||p_investment_id,
            'financial', 'success', p_investment_id::TEXT, 'investment');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- SECTION 11: ROW-LEVEL SECURITY (auth.uid() based)
-- ============================================================

DROP POLICY IF EXISTS "Public check-ins are viewable by owner" ON daily_check_ins;
CREATE POLICY "Public check-ins are viewable by owner" ON daily_check_ins FOR SELECT USING (auth.uid() = user_id);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_investments ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_check_ins ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE spin_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ads ENABLE ROW LEVEL SECURITY;

-- === USER Policies (granular per operation) ===

-- profiles: SELECT + UPDATE own only
DROP POLICY IF EXISTS p_user_select_profile ON profiles;
CREATE POLICY p_user_select_profile ON profiles FOR SELECT USING (id = auth.uid());
DROP POLICY IF EXISTS p_user_update_profile ON profiles;
CREATE POLICY p_user_update_profile ON profiles FOR UPDATE USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- wallets: SELECT own only (NO insert/update/delete by user)
DROP POLICY IF EXISTS p_user_select_wallet ON wallets;
CREATE POLICY p_user_select_wallet ON wallets FOR SELECT USING (user_id = auth.uid());

-- transactions: SELECT own + INSERT requests (deposit/withdrawal)
DROP POLICY IF EXISTS p_user_select_txn ON transactions;
CREATE POLICY p_user_select_txn ON transactions FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS p_user_insert_txn ON transactions;
CREATE POLICY p_user_insert_txn ON transactions FOR INSERT
    WITH CHECK (user_id = auth.uid() AND type IN ('deposit', 'withdrawal'));

-- user_investments: SELECT own only
DROP POLICY IF EXISTS p_user_select_inv ON user_investments;
CREATE POLICY p_user_select_inv ON user_investments FOR SELECT USING (user_id = auth.uid());

-- loans: SELECT own only
DROP POLICY IF EXISTS p_user_select_loans ON loans;
CREATE POLICY p_user_select_loans ON loans FOR SELECT USING (user_id = auth.uid());

-- kyc_documents: SELECT + INSERT own
DROP POLICY IF EXISTS p_user_select_kyc ON kyc_documents;
CREATE POLICY p_user_select_kyc ON kyc_documents FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS p_user_insert_kyc ON kyc_documents;
CREATE POLICY p_user_insert_kyc ON kyc_documents FOR INSERT WITH CHECK (user_id = auth.uid());

-- user_activities: SELECT own only
DROP POLICY IF EXISTS p_user_select_activity ON user_activities;
CREATE POLICY p_user_select_activity ON user_activities FOR SELECT USING (user_id = auth.uid());

-- user_points: SELECT own only
DROP POLICY IF EXISTS p_user_select_points ON user_points;
CREATE POLICY p_user_select_points ON user_points FOR SELECT USING (user_id = auth.uid());

-- chat: SELECT + INSERT own conversations/messages
DROP POLICY IF EXISTS p_user_select_conv ON chat_conversations;
CREATE POLICY p_user_select_conv ON chat_conversations FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS p_user_select_msg ON chat_messages;
CREATE POLICY p_user_select_msg ON chat_messages FOR SELECT USING (
    conversation_id IN (SELECT id FROM chat_conversations WHERE user_id = auth.uid())
);
DROP POLICY IF EXISTS p_user_insert_msg ON chat_messages;
CREATE POLICY p_user_insert_msg ON chat_messages FOR INSERT WITH CHECK (
    sender_id = auth.uid() AND sender_type = 'user'
    AND conversation_id IN (SELECT id FROM chat_conversations WHERE user_id = auth.uid())
);

-- notifications: SELECT own + global
DROP POLICY IF EXISTS p_user_select_notif ON notifications;
CREATE POLICY p_user_select_notif ON notifications FOR SELECT USING (
    target = 'all' OR target_user_id = auth.uid()
);

-- spin_results: SELECT own only
DROP POLICY IF EXISTS p_user_select_spin ON spin_results;
CREATE POLICY p_user_select_spin ON spin_results FOR SELECT USING (user_id = auth.uid());

-- subscriptions: SELECT own only
DROP POLICY IF EXISTS p_user_select_sub ON subscriptions;
CREATE POLICY p_user_select_sub ON subscriptions FOR SELECT USING (user_id = auth.uid());

-- ads: SELECT active + non-expired only
DROP POLICY IF EXISTS p_user_select_ads ON ads;
CREATE POLICY p_user_select_ads ON ads FOR SELECT USING (
    is_active = TRUE AND (expires_at IS NULL OR expires_at > NOW())
);

-- === ADMIN Policies (is_admin() check – CANNOT be spoofed) ===

DROP POLICY IF EXISTS p_admin_profiles ON profiles;
CREATE POLICY p_admin_profiles ON profiles FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS p_admin_wallets ON wallets;
CREATE POLICY p_admin_wallets ON wallets FOR SELECT USING (is_admin());
DROP POLICY IF EXISTS p_admin_txns_select ON transactions;
CREATE POLICY p_admin_txns_select ON transactions FOR SELECT USING (is_admin());
DROP POLICY IF EXISTS p_admin_txns_insert ON transactions;
CREATE POLICY p_admin_txns_insert ON transactions FOR INSERT WITH CHECK (is_admin());
-- NOTE: UPDATE on transactions handled by SECURITY DEFINER RPCs only
DROP POLICY IF EXISTS p_admin_investments ON user_investments;
CREATE POLICY p_admin_investments ON user_investments FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS p_admin_loans ON loans;
CREATE POLICY p_admin_loans ON loans FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS p_admin_kyc ON kyc_documents;
CREATE POLICY p_admin_kyc ON kyc_documents FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS p_admin_activities ON user_activities;
CREATE POLICY p_admin_activities ON user_activities FOR SELECT USING (is_admin());
DROP POLICY IF EXISTS p_admin_points ON user_points;
CREATE POLICY p_admin_points ON user_points FOR SELECT USING (is_admin());
DROP POLICY IF EXISTS p_admin_convs ON chat_conversations;
CREATE POLICY p_admin_convs ON chat_conversations FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS p_admin_msgs ON chat_messages;
CREATE POLICY p_admin_msgs ON chat_messages FOR ALL USING (is_admin()) WITH CHECK (is_admin());
DROP POLICY IF EXISTS p_admin_notif ON notifications;
CREATE POLICY p_admin_notif ON notifications FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS p_admin_spin ON spin_results;
CREATE POLICY p_admin_spin ON spin_results FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS p_admin_sub ON subscriptions;
CREATE POLICY p_admin_sub ON subscriptions FOR ALL USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS p_admin_ads ON ads;
CREATE POLICY p_admin_ads ON ads FOR ALL USING (is_admin()) WITH CHECK (is_admin());

-- ============================================================
-- STORAGE: KYC Documents Bucket & Policies
-- ============================================================

-- 1. Ensure the 'documents' bucket exists
INSERT INTO storage.buckets (id, name, public)
SELECT 'documents', 'documents', true
WHERE NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id = 'documents');

-- 2. Policy: Allow authenticated users to upload their own KYC documents
DROP POLICY IF EXISTS "Allow authenticated uploads to KYC folder" ON storage.objects;
CREATE POLICY "Allow authenticated uploads to KYC folder"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'documents' AND
    (storage.foldername(name))[1] = 'kyc' AND
    (storage.foldername(name))[2] = auth.uid()::text
);

-- 3. Policy: Allow users to view their own documents
DROP POLICY IF EXISTS "Allow users to view their own documents" ON storage.objects;
CREATE POLICY "Allow users to view their own documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'documents' AND
    (storage.foldername(name))[1] = 'kyc' AND
    (storage.foldername(name))[2] = auth.uid()::text
);

-- 4. Policy: Allow admins to view all documents
DROP POLICY IF EXISTS "Allow admins to view all kyc documents" ON storage.objects;
CREATE POLICY "Allow admins to view all kyc documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
    bucket_id = 'documents' AND
    is_admin()
);

-- ============================================================
-- SECTION 12: VIEWS
-- ============================================================

-- (View definition moved to end of SECTION 12 for consolidation)

-- Admin dashboard as SECURITY DEFINER function (bypasses RLS)
DROP FUNCTION IF EXISTS fn_admin_dashboard() CASCADE;
CREATE OR REPLACE FUNCTION fn_admin_dashboard()
RETURNS TABLE (
    total_users BIGINT, active_users BIGINT, pending_kyc BIGINT,
    total_balance NUMERIC, total_invested NUMERIC,
    pending_txns BIGINT, active_loans BIGINT, delayed_loans BIGINT, active_agents BIGINT
) AS $$
BEGIN
    RETURN QUERY SELECT
        (SELECT COUNT(*) FROM profiles),
        (SELECT COUNT(*) FROM profiles WHERE status = 'active'),
        (SELECT COUNT(*) FROM profiles WHERE kyc_status = 'pending'),
        (SELECT COALESCE(SUM(available_balance),0) FROM wallets),
        (SELECT COALESCE(SUM(invested_balance),0) FROM wallets),
        (SELECT COUNT(*) FROM transactions WHERE status = 'pending'),
        (SELECT COUNT(*) FROM loans WHERE status = 'current'),
        (SELECT COUNT(*) FROM loans WHERE status = 'delayed'),
        (SELECT COUNT(*) FROM agents WHERE status = 'active');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- SECTION 13: SEED DATA
-- ============================================================

INSERT INTO currencies (name, code, symbol, rate, decimal_places, is_base, is_active, flag) VALUES
    ('الدولار الأمريكي', 'USD', '$', 1.00000000, 2, TRUE, TRUE, '🇺🇸'),
    ('الدينار العراقي', 'IQD', 'د.ع', 1320.00000000, 0, FALSE, TRUE, '🇮🇶'),
    ('الدينار الكويتي', 'KWD', 'د.ك', 0.30710000, 3, FALSE, TRUE, '🇰🇼'),
    ('الريال السعودي', 'SAR', 'ر.س', 3.75000000, 2, FALSE, TRUE, '🇸🇦'),
    ('الدرهم الإماراتي', 'AED', 'د.إ', 3.67250000, 2, FALSE, TRUE, '🇦🇪'),
    ('الدينار الأردني', 'JOD', 'د.أ', 0.70900000, 3, FALSE, TRUE, '🇯🇴'),
    ('الجنيه المصري', 'EGP', 'ج.م', 47.10000000, 2, FALSE, TRUE, '🇪🇬'),
    ('الليرة التركية', 'TRY', '₺', 15.59000000, 2, FALSE, TRUE, '🇹🇷'),
    ('اليورو', 'EUR', '€', 0.84610000, 2, FALSE, TRUE, '🇪🇺'),
    ('الفرنك السويسري', 'CHF', 'CHF', 0.77540000, 2, FALSE, TRUE, '🇨🇭'),
    ('الين الياباني', 'JPY', '¥', 155.90000000, 0, FALSE, TRUE, '🇯🇵')
ON CONFLICT (code) DO NOTHING;

INSERT INTO system_settings (
    pause_deposits, pause_withdrawals, pause_profits, pause_investments,
    pause_loans, system_freeze, is_maintenance_mode, maintenance_message
)
SELECT 
    FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE,
    'النظام حالياً في مرحلة التحديث الدوري لضمان أعلى معايير الأمان والامتثال. سنعود قريباً.'
WHERE NOT EXISTS (SELECT 1 FROM system_settings);

INSERT INTO countries (code, name, dial_code, flag, is_supported) VALUES
    ('IQ', 'العراق', '+964', '🇮🇶', TRUE),
    ('SA', 'المملكة العربية السعودية', '+966', '🇸🇦', TRUE),
    ('AE', 'الإمارات العربية المتحدة', '+971', '🇦🇪', TRUE),
    ('KW', 'الكويت', '+965', '🇰🇼', TRUE),
    ('JO', 'الأردن', '+962', '🇯🇴', TRUE),
    ('EG', 'مصر', '+20', '🇪🇬', TRUE),
    ('OM', 'عمان', '+968', '🇴🇲', TRUE),
    ('BH', 'البحرين', '+973', '🇧🇭', TRUE),
    ('QA', 'قطر', '+974', '🇶🇦', TRUE),
    ('TR', 'تركيا', '+90', '🇹🇷', TRUE),
    ('SY', 'سوريا', '+963', '🇸🇾', TRUE),
    ('LB', 'لبنان', '+961', '🇱🇧', TRUE),
    ('YE', 'اليمن', '+967', '🇾🇪', TRUE),
    ('PS', 'فلسطين', '+970', '🇵🇸', TRUE),
    ('US', 'الولايات المتحدة', '+1', '🇺🇸', TRUE),
    ('GB', 'المملكة المتحدة', '+44', '🇬🇧', TRUE),
    ('CA', 'كندا', '+1', '🇨🇦', TRUE),
    ('DE', 'ألمانيا', '+49', '🇩🇪', TRUE),
    ('FR', 'فرنسا', '+33', '🇫🇷', TRUE),
    ('IT', 'إيطاليا', '+39', '🇮🇹', TRUE),
    ('ES', 'إسبانيا', '+34', '🇪🇸', TRUE),
    ('CN', 'الصين', '+86', '🇨🇳', TRUE),
    ('IN', 'الهند', '+91', '🇮🇳', TRUE)
ON CONFLICT (code) DO NOTHING;

-- 10.6 DAILY CHECK-IN
DROP FUNCTION IF EXISTS public.daily_check_in() CASCADE;
CREATE OR REPLACE FUNCTION public.daily_check_in()
RETURNS json AS $$
DECLARE
    v_user_id UUID;
    v_last_checkin TIMESTAMPTZ;
    v_current_streak INTEGER := 1;
    v_points_to_award INTEGER := 10; -- Base points
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN json_build_object('success', FALSE, 'error', 'Unauthorized');
    END IF;

    -- 1. Check if already checked in today
    SELECT created_at INTO v_last_checkin
    FROM daily_check_ins
    WHERE user_id = v_user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE THEN
        RETURN json_build_object('success', FALSE, 'error', 'Already checked in today');
    END IF;

    -- 2. Calculate streak
    IF v_last_checkin IS NOT NULL AND v_last_checkin::date = CURRENT_DATE - INTERVAL '1 day' THEN
        SELECT streak INTO v_current_streak
        FROM daily_check_ins
        WHERE user_id = v_user_id
        ORDER BY created_at DESC
        LIMIT 1;
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    -- 3. Calculate points (Bonus for streak every 7 days)
    v_points_to_award := 10;
    IF v_current_streak % 7 = 0 THEN
        v_points_to_award := 50;
    END IF;

    -- 4. Record check-in
    INSERT INTO daily_check_ins (user_id, streak, points_awarded)
    VALUES (v_user_id, v_current_streak, v_points_to_award);

    -- 5. Award points
    INSERT INTO point_history (user_id, points, type, description)
    VALUES (v_user_id, v_points_to_award, 'earn', 'Daily check-in streak: ' || v_current_streak);

    INSERT INTO user_points (user_id, total_earned)
    VALUES (v_user_id, v_points_to_award)
    ON CONFLICT (user_id) DO UPDATE
    SET total_earned = user_points.total_earned + EXCLUDED.total_earned,
        updated_at = CURRENT_TIMESTAMP;

    RETURN json_build_object(
        'success', TRUE,
        'streak', v_current_streak,
        'points_awarded', v_points_to_award,
        'message', 'Check-in successful!'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', FALSE, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- SECTION 12: VIEWS
-- ============================================================

DROP VIEW IF EXISTS v_user_dashboard;
CREATE OR REPLACE VIEW v_user_dashboard AS
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

-- ============================================================
-- END OF SCHEMA v3.1 (Audit-Corrected)
-- ============================================================
-- 25 Tables | 14 Enums | 6 SECURITY DEFINER RPCs
-- 4 Safety Triggers | auth.users Integration
-- 22 RLS Policies (auth.uid based) | Dashboard Function
-- ============================================================
