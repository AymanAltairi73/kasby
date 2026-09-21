-- Kasby Marketplace — Enterprise schema (design-only migration)
-- Apply when connecting user app and admin panel to Supabase.

-- ── Extensions ─────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Enums ──────────────────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE marketplace_stock_status AS ENUM ('inStock', 'lowStock', 'outOfStock');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE marketplace_order_status AS ENUM (
    'pending', 'processing', 'providerAccepted', 'delivered',
    'completed', 'failed', 'cancelled', 'refundRequested', 'refunded'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE marketplace_payment_method AS ENUM ('wallet', 'ksp');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE marketplace_promotion_type AS ENUM (
    'banner', 'coupon', 'campaign', 'flashSale', 'dailyDeal',
    'weekendDeal', 'limitedTimeOffer', 'featuredOffer'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE marketplace_provider_status AS ENUM ('active', 'inactive', 'deprecated', 'error');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── Audit trigger helper ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION marketplace_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── Categories ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  icon_name TEXT DEFAULT 'category',
  sort_order INT NOT NULL DEFAULT 0,
  is_visible BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_categories_sort
  ON marketplace_categories (sort_order, is_visible);

-- ── Brands ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_brands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES marketplace_categories(id) ON DELETE CASCADE,
  slug TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  logo_url TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (category_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_brands_category
  ON marketplace_brands (category_id, is_active, sort_order);

-- ── Products (product lines under brand) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id UUID NOT NULL REFERENCES marketplace_brands(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES marketplace_categories(id) ON DELETE CASCADE,
  slug TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  description_en TEXT DEFAULT '',
  description_ar TEXT DEFAULT '',
  instructions_en TEXT DEFAULT '',
  instructions_ar TEXT DEFAULT '',
  terms_en TEXT DEFAULT '',
  terms_ar TEXT DEFAULT '',
  image_url TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (brand_id, slug)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_products_brand
  ON marketplace_products (brand_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_marketplace_products_category
  ON marketplace_products (category_id, is_active);

-- ── Product Variants (purchasable SKUs) ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES marketplace_products(id) ON DELETE CASCADE,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  provider_sku TEXT NOT NULL,
  wallet_price NUMERIC(12, 2) NOT NULL CHECK (wallet_price >= 0),
  ksp_price NUMERIC(12, 2) CHECK (ksp_price IS NULL OR ksp_price >= 0),
  original_price NUMERIC(12, 2) CHECK (original_price IS NULL OR original_price >= 0),
  discount_percent INT DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
  stock_status marketplace_stock_status NOT NULL DEFAULT 'inStock',
  sort_order INT NOT NULL DEFAULT 0,
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  estimated_delivery TEXT DEFAULT 'Instant',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (product_id, provider_sku)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_variants_product
  ON marketplace_product_variants (product_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_marketplace_variants_featured
  ON marketplace_product_variants (is_featured) WHERE is_featured = TRUE;

-- ── Provider Mapping (variant ↔ external provider) ───────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_provider_mapping (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  variant_id UUID NOT NULL UNIQUE REFERENCES marketplace_product_variants(id) ON DELETE CASCADE,
  provider_name TEXT NOT NULL,
  provider_product_id TEXT NOT NULL,
  provider_sku TEXT NOT NULL,
  provider_category TEXT,
  provider_status marketplace_provider_status NOT NULL DEFAULT 'active',
  provider_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_provider_mapping_name
  ON marketplace_provider_mapping (provider_name, provider_status);

-- ── Coupons ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  title_en TEXT NOT NULL,
  title_ar TEXT NOT NULL,
  discount_percent NUMERIC(5, 2) CHECK (discount_percent IS NULL OR discount_percent >= 0),
  discount_amount NUMERIC(12, 2) CHECK (discount_amount IS NULL OR discount_amount >= 0),
  min_order_amount NUMERIC(12, 2) DEFAULT 0,
  max_uses INT,
  used_count INT NOT NULL DEFAULT 0,
  starts_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_coupons_active
  ON marketplace_coupons (code, is_active);

-- ── Promotions / Campaigns ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type marketplace_promotion_type NOT NULL,
  title_en TEXT NOT NULL,
  title_ar TEXT NOT NULL,
  description_en TEXT DEFAULT '',
  description_ar TEXT DEFAULT '',
  coupon_id UUID REFERENCES marketplace_coupons(id) ON DELETE SET NULL,
  banner_image_url TEXT,
  discount_percent NUMERIC(5, 2),
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_promotions_active
  ON marketplace_promotions (type, is_active, starts_at, ends_at);

-- ── Rewards ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL,
  title_en TEXT NOT NULL,
  title_ar TEXT NOT NULL,
  ksp_amount NUMERIC(12, 2),
  wallet_amount NUMERIC(12, 2),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── Settings (singleton row) ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_settings (
  id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  wallet_payment_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  ksp_payment_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  maintenance_mode BOOLEAN NOT NULL DEFAULT FALSE,
  default_provider TEXT DEFAULT 'mock',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO marketplace_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- ── Orders ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT NOT NULL UNIQUE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subtotal_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  coupon_code TEXT,
  payment_method marketplace_payment_method NOT NULL,
  status marketplace_order_status NOT NULL DEFAULT 'pending',
  delivery_code TEXT,
  delivery_info TEXT,
  provider_name TEXT,
  provider_order_id TEXT,
  timeline JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_user
  ON marketplace_orders (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_status
  ON marketplace_orders (status, created_at DESC);

-- ── Order Items ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES marketplace_orders(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES marketplace_product_variants(id) ON DELETE SET NULL,
  product_id UUID REFERENCES marketplace_products(id) ON DELETE SET NULL,
  brand_id UUID REFERENCES marketplace_brands(id) ON DELETE SET NULL,
  category_id UUID REFERENCES marketplace_categories(id) ON DELETE SET NULL,
  variant_name TEXT NOT NULL,
  product_name TEXT NOT NULL,
  brand_name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_wallet_price NUMERIC(12, 2) NOT NULL,
  unit_ksp_price NUMERIC(12, 2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_order_items_order
  ON marketplace_order_items (order_id);

-- ── Cart (server-side optional sync) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_cart (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  variant_id UUID NOT NULL REFERENCES marketplace_product_variants(id) ON DELETE CASCADE,
  quantity INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, variant_id)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_cart_user
  ON marketplace_cart (user_id);

-- ── Wishlist ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_wishlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  variant_id UUID NOT NULL REFERENCES marketplace_product_variants(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, variant_id)
);

CREATE INDEX IF NOT EXISTS idx_marketplace_wishlist_user
  ON marketplace_wishlist (user_id);

-- ── Transactions (financial audit trail) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES marketplace_orders(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  payment_method marketplace_payment_method NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed',
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_transactions_user
  ON marketplace_transactions (user_id, created_at DESC);

-- ── Provider Logs (integration debugging) ────────────────────────────────────
CREATE TABLE IF NOT EXISTS marketplace_provider_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_name TEXT NOT NULL,
  order_id UUID REFERENCES marketplace_orders(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES marketplace_product_variants(id) ON DELETE SET NULL,
  request_payload JSONB,
  response_payload JSONB,
  status_code INT,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_provider_logs_provider
  ON marketplace_provider_logs (provider_name, created_at DESC);

-- ── Updated_at triggers ──────────────────────────────────────────────────────
DO $$ DECLARE t TEXT; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'marketplace_categories', 'marketplace_brands', 'marketplace_products',
    'marketplace_product_variants', 'marketplace_provider_mapping',
    'marketplace_coupons', 'marketplace_promotions', 'marketplace_rewards',
    'marketplace_settings', 'marketplace_orders', 'marketplace_order_items',
    'marketplace_cart', 'marketplace_transactions'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION marketplace_set_updated_at()',
      t, t
    );
  END LOOP;
END $$;

-- ── Row Level Security ───────────────────────────────────────────────────────
ALTER TABLE marketplace_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_provider_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_cart ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_wishlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_provider_logs ENABLE ROW LEVEL SECURITY;

-- Public catalog read (authenticated users)
CREATE POLICY marketplace_categories_read ON marketplace_categories
  FOR SELECT TO authenticated USING (is_visible = TRUE);

CREATE POLICY marketplace_brands_read ON marketplace_brands
  FOR SELECT TO authenticated USING (is_active = TRUE);

CREATE POLICY marketplace_products_read ON marketplace_products
  FOR SELECT TO authenticated USING (is_active = TRUE);

CREATE POLICY marketplace_variants_read ON marketplace_product_variants
  FOR SELECT TO authenticated USING (is_active = TRUE);

CREATE POLICY marketplace_promotions_read ON marketplace_promotions
  FOR SELECT TO authenticated USING (is_active = TRUE);

CREATE POLICY marketplace_rewards_read ON marketplace_rewards
  FOR SELECT TO authenticated USING (is_active = TRUE);

CREATE POLICY marketplace_settings_read ON marketplace_settings
  FOR SELECT TO authenticated USING (TRUE);

-- User-owned data
CREATE POLICY marketplace_orders_own ON marketplace_orders
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY marketplace_order_items_own ON marketplace_order_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM marketplace_orders o
      WHERE o.id = order_id AND o.user_id = auth.uid()
    )
  );

CREATE POLICY marketplace_cart_own ON marketplace_cart
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY marketplace_wishlist_own ON marketplace_wishlist
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY marketplace_transactions_own ON marketplace_transactions
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- Admin policies (service_role bypasses RLS; authenticated admins via app_metadata)
-- TODO: Replace with dedicated admin role check when admin auth is wired.
CREATE POLICY marketplace_admin_all_categories ON marketplace_categories
  FOR ALL TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_all_brands ON marketplace_brands
  FOR ALL TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_all_products ON marketplace_products
  FOR ALL TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_all_variants ON marketplace_product_variants
  FOR ALL TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_all_coupons ON marketplace_coupons
  FOR ALL TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_all_promotions ON marketplace_promotions
  FOR ALL TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_all_settings ON marketplace_settings
  FOR ALL TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
  WITH CHECK ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_read_orders ON marketplace_orders
  FOR SELECT TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_read_provider_logs ON marketplace_provider_logs
  FOR SELECT TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

CREATE POLICY marketplace_admin_read_provider_mapping ON marketplace_provider_mapping
  FOR SELECT TO authenticated
  USING ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');
