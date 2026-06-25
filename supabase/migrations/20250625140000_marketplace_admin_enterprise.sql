-- Marketplace enterprise catalog + admin management layer.
-- Apply via: supabase db push  OR  supabase migration up

-- ── Categories ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_categories (
  id TEXT PRIMARY KEY,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  icon_name TEXT NOT NULL DEFAULT 'category',
  sort_order INT NOT NULL DEFAULT 0,
  is_visible BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Brands ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_brands (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL REFERENCES public.marketplace_categories(id) ON DELETE CASCADE,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  logo_url TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Products ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_products (
  id TEXT PRIMARY KEY,
  brand_id TEXT REFERENCES public.marketplace_brands(id) ON DELETE SET NULL,
  category_id TEXT NOT NULL REFERENCES public.marketplace_categories(id) ON DELETE CASCADE,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  description_en TEXT NOT NULL DEFAULT '',
  description_ar TEXT NOT NULL DEFAULT '',
  image_url TEXT,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_popular BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Variants (purchasable SKUs) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_product_variants (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES public.marketplace_products(id) ON DELETE CASCADE,
  brand_id TEXT NOT NULL REFERENCES public.marketplace_brands(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES public.marketplace_categories(id) ON DELETE CASCADE,
  name_en TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  provider_sku TEXT NOT NULL DEFAULT '',
  wallet_price NUMERIC(18, 4) NOT NULL DEFAULT 0 CHECK (wallet_price >= 0),
  ksp_price NUMERIC(18, 4),
  original_price NUMERIC(18, 4),
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  stock_status TEXT NOT NULL DEFAULT 'inStock' CHECK (
    stock_status IN ('inStock', 'lowStock', 'outOfStock', 'unavailable')
  ),
  image_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Provider mapping ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_provider_mapping (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  variant_id TEXT NOT NULL REFERENCES public.marketplace_product_variants(id) ON DELETE CASCADE,
  provider_name TEXT NOT NULL DEFAULT 'reloadly',
  provider_product_id TEXT NOT NULL,
  provider_sku TEXT NOT NULL DEFAULT '',
  provider_category TEXT NOT NULL DEFAULT '',
  provider_status TEXT NOT NULL DEFAULT 'active' CHECK (
    provider_status IN ('active', 'inactive', 'deprecated', 'error', 'pending')
  ),
  provider_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT marketplace_provider_mapping_variant_unique UNIQUE (variant_id, provider_name)
);

-- ── Coupons ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_coupons (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  title_en TEXT NOT NULL,
  title_ar TEXT NOT NULL,
  discount_percent NUMERIC(5, 2),
  discount_amount NUMERIC(18, 4),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Promotions ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_promotions (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title_en TEXT NOT NULL,
  title_ar TEXT NOT NULL,
  coupon_code TEXT,
  discount_percent NUMERIC(5, 2),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Rewards ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_rewards (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title_en TEXT NOT NULL,
  title_ar TEXT NOT NULL,
  ksp_amount NUMERIC(18, 4),
  wallet_amount NUMERIC(18, 4),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Settings (singleton) ──────────────────────────────────────────────────
-- Supports legacy schemas where id is INTEGER as well as TEXT 'default'.
CREATE TABLE IF NOT EXISTS public.marketplace_settings (
  id TEXT PRIMARY KEY DEFAULT 'default',
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  wallet_payment_enabled BOOLEAN NOT NULL DEFAULT true,
  ksp_payment_enabled BOOLEAN NOT NULL DEFAULT true,
  maintenance_mode BOOLEAN NOT NULL DEFAULT false,
  provider_environment TEXT NOT NULL DEFAULT 'sandbox',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.marketplace_settings
  ADD COLUMN IF NOT EXISTS is_enabled BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS wallet_payment_enabled BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS ksp_payment_enabled BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS maintenance_mode BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS provider_environment TEXT DEFAULT 'sandbox',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

DO $$
DECLARE
  v_id_type TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.marketplace_settings LIMIT 1) THEN
    SELECT t.typname INTO v_id_type
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_type t ON t.oid = a.atttypid
    WHERE n.nspname = 'public'
      AND c.relname = 'marketplace_settings'
      AND a.attname = 'id'
      AND NOT a.attisdropped;

    IF v_id_type IN ('int2', 'int4', 'int8') THEN
      INSERT INTO public.marketplace_settings (id) VALUES (1);
    ELSE
      INSERT INTO public.marketplace_settings (id) VALUES ('default');
    END IF;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ── Catalog sync runs ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_catalog_sync_runs (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  provider_name TEXT NOT NULL DEFAULT 'reloadly',
  environment TEXT NOT NULL DEFAULT 'sandbox',
  status TEXT NOT NULL DEFAULT 'running' CHECK (
    status IN ('running', 'completed', 'failed')
  ),
  products_imported INT NOT NULL DEFAULT 0,
  products_updated INT NOT NULL DEFAULT 0,
  products_removed INT NOT NULL DEFAULT 0,
  new_products INT NOT NULL DEFAULT 0,
  error_message TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ
);

-- ── Catalog validation report ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.marketplace_catalog_validation (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  section TEXT NOT NULL,
  product_name TEXT NOT NULL,
  status TEXT NOT NULL CHECK (
    status IN (
      'Available',
      'Not Supported by Reloadly',
      'Catalog Validation Pending',
      'Requires Secondary Provider'
    )
  ),
  match_count INT NOT NULL DEFAULT 0,
  sample_matches JSONB NOT NULL DEFAULT '[]'::jsonb,
  catalog_accessible BOOLEAN NOT NULL DEFAULT false,
  source TEXT,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Schema alignment (pre-existing tables may lack columns) ───────────────
ALTER TABLE public.marketplace_categories
  ADD COLUMN IF NOT EXISTS slug TEXT,
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS name_ar TEXT,
  ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'category',
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_visible BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS idx_marketplace_categories_slug
  ON public.marketplace_categories (slug)
  WHERE slug IS NOT NULL;

ALTER TABLE public.marketplace_brands
  ADD COLUMN IF NOT EXISTS category_id TEXT,
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS name_ar TEXT,
  ADD COLUMN IF NOT EXISTS logo_url TEXT,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.marketplace_products
  ADD COLUMN IF NOT EXISTS brand_id TEXT,
  ADD COLUMN IF NOT EXISTS category_id TEXT,
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS name_ar TEXT,
  ADD COLUMN IF NOT EXISTS description_en TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS description_ar TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

ALTER TABLE public.marketplace_product_variants
  ADD COLUMN IF NOT EXISTS product_id TEXT,
  ADD COLUMN IF NOT EXISTS brand_id TEXT,
  ADD COLUMN IF NOT EXISTS category_id TEXT,
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS name_ar TEXT,
  ADD COLUMN IF NOT EXISTS provider_sku TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS wallet_price NUMERIC(18, 4) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ksp_price NUMERIC(18, 4),
  ADD COLUMN IF NOT EXISTS original_price NUMERIC(18, 4),
  ADD COLUMN IF NOT EXISTS is_featured BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS stock_status TEXT DEFAULT 'inStock',
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- ── Indexes (after column alignment) ──────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_marketplace_brands_category
  ON public.marketplace_brands (category_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_marketplace_products_brand
  ON public.marketplace_products (brand_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_marketplace_variants_product
  ON public.marketplace_product_variants (product_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_marketplace_variants_active
  ON public.marketplace_product_variants (is_active, category_id);

CREATE INDEX IF NOT EXISTS idx_marketplace_catalog_validation_generated
  ON public.marketplace_catalog_validation (generated_at DESC);

-- ── updated_at triggers ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'marketplace_categories',
    'marketplace_brands',
    'marketplace_products',
    'marketplace_product_variants',
    'marketplace_provider_mapping',
    'marketplace_coupons',
    'marketplace_promotions',
    'marketplace_rewards',
    'marketplace_settings'
  ] LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_%s_updated ON public.%I;
       CREATE TRIGGER trg_%s_updated
         BEFORE UPDATE ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.fn_marketplace_touch_updated_at();',
      t, t, t, t
    );
  END LOOP;
END;
$$;

-- ── RLS ───────────────────────────────────────────────────────────────────
ALTER TABLE public.marketplace_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_provider_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_catalog_sync_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_catalog_validation ENABLE ROW LEVEL SECURITY;

-- Public catalog read for authenticated users
DROP POLICY IF EXISTS marketplace_categories_read ON public.marketplace_categories;
CREATE POLICY marketplace_categories_read ON public.marketplace_categories
  FOR SELECT TO authenticated USING (is_visible = true OR public.is_admin());

DROP POLICY IF EXISTS marketplace_brands_read ON public.marketplace_brands;
CREATE POLICY marketplace_brands_read ON public.marketplace_brands
  FOR SELECT TO authenticated USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS marketplace_products_read ON public.marketplace_products;
CREATE POLICY marketplace_products_read ON public.marketplace_products
  FOR SELECT TO authenticated USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS marketplace_variants_read ON public.marketplace_product_variants;
CREATE POLICY marketplace_variants_read ON public.marketplace_product_variants
  FOR SELECT TO authenticated USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS marketplace_provider_mapping_read ON public.marketplace_provider_mapping;
CREATE POLICY marketplace_provider_mapping_read ON public.marketplace_provider_mapping
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS marketplace_coupons_read ON public.marketplace_coupons;
CREATE POLICY marketplace_coupons_read ON public.marketplace_coupons
  FOR SELECT TO authenticated USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS marketplace_promotions_read ON public.marketplace_promotions;
CREATE POLICY marketplace_promotions_read ON public.marketplace_promotions
  FOR SELECT TO authenticated USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS marketplace_rewards_read ON public.marketplace_rewards;
CREATE POLICY marketplace_rewards_read ON public.marketplace_rewards
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS marketplace_settings_read ON public.marketplace_settings;
CREATE POLICY marketplace_settings_read ON public.marketplace_settings
  FOR SELECT TO authenticated USING (true);

-- Admin full access on catalog tables
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'marketplace_categories',
    'marketplace_brands',
    'marketplace_products',
    'marketplace_product_variants',
    'marketplace_provider_mapping',
    'marketplace_coupons',
    'marketplace_promotions',
    'marketplace_rewards',
    'marketplace_settings',
    'marketplace_catalog_sync_runs',
    'marketplace_catalog_validation'
  ] LOOP
    EXECUTE format(
      'DROP POLICY IF EXISTS %I_admin_all ON public.%I;
       CREATE POLICY %I_admin_all ON public.%I
         FOR ALL TO authenticated
         USING (public.is_admin())
         WITH CHECK (public.is_admin());',
      t, t, t, t
    );
  END LOOP;
END;
$$;

-- Admin order access
DROP POLICY IF EXISTS marketplace_orders_admin_all ON public.marketplace_orders;
CREATE POLICY marketplace_orders_admin_all ON public.marketplace_orders
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS marketplace_order_items_admin_all ON public.marketplace_order_items;
CREATE POLICY marketplace_order_items_admin_all ON public.marketplace_order_items
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ── Seed default categories ─────────────────────────────────────────────────
-- Legacy schemas may use UUID primary keys; new schemas use TEXT slug ids.
DO $$
DECLARE
  v_id_type TEXT;
BEGIN
  SELECT t.typname INTO v_id_type
  FROM pg_attribute a
  JOIN pg_class c ON c.oid = a.attrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_type t ON t.oid = a.atttypid
  WHERE n.nspname = 'public'
    AND c.relname = 'marketplace_categories'
    AND a.attname = 'id'
    AND NOT a.attisdropped;

  IF v_id_type IN ('text', 'varchar', 'bpchar') THEN
    INSERT INTO public.marketplace_categories (id, slug, name_en, name_ar, icon_name, sort_order)
    VALUES
      ('cat_games', 'cat_games', 'Games', 'الألعاب', 'sports_esports', 1),
      ('cat_gift_cards', 'cat_gift_cards', 'Gift Cards', 'بطاقات الهدايا', 'card_giftcard', 2),
      ('cat_subscriptions', 'cat_subscriptions', 'Subscriptions', 'الاشتراكات', 'subscriptions', 3),
      ('cat_digital_services', 'cat_digital_services', 'Digital Services', 'الخدمات الرقمية', 'wifi', 4),
      ('cat_rewards', 'cat_rewards', 'Rewards', 'المكافآت', 'emoji_events', 5),
      ('cat_ksp_exclusive', 'cat_ksp_exclusive', 'KSP Exclusive', 'حصري KSP', 'diamond', 6),
      ('cat_featured', 'cat_featured', 'Featured Offers', 'عروض مميزة', 'star', 7),
      ('cat_new_arrivals', 'cat_new_arrivals', 'New Arrivals', 'وصل حديثاً', 'new_releases', 8)
    ON CONFLICT (id) DO NOTHING;
  ELSIF v_id_type = 'uuid' THEN
    INSERT INTO public.marketplace_categories (id, slug, name_en, name_ar, icon_name, sort_order)
    SELECT gen_random_uuid(), v.slug, v.name_en, v.name_ar, v.icon_name, v.sort_order
    FROM (VALUES
      ('cat_games', 'Games', 'الألعاب', 'sports_esports', 1),
      ('cat_gift_cards', 'Gift Cards', 'بطاقات الهدايا', 'card_giftcard', 2),
      ('cat_subscriptions', 'Subscriptions', 'الاشتراكات', 'subscriptions', 3),
      ('cat_digital_services', 'Digital Services', 'الخدمات الرقمية', 'wifi', 4),
      ('cat_rewards', 'Rewards', 'المكافآت', 'emoji_events', 5),
      ('cat_ksp_exclusive', 'KSP Exclusive', 'حصري KSP', 'diamond', 6),
      ('cat_featured', 'Featured Offers', 'عروض مميزة', 'star', 7),
      ('cat_new_arrivals', 'New Arrivals', 'وصل حديثاً', 'new_releases', 8)
    ) AS v(slug, name_en, name_ar, icon_name, sort_order)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.marketplace_categories c WHERE c.slug = v.slug
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- ── RPC: admin dashboard stats ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_marketplace_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSONB;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden');
  END IF;

  SELECT jsonb_build_object(
    'success', true,
    'totalProducts', (SELECT COUNT(*) FROM marketplace_products),
    'totalCategories', (SELECT COUNT(*) FROM marketplace_categories),
    'totalBrands', (SELECT COUNT(*) FROM marketplace_brands),
    'totalVariants', (SELECT COUNT(*) FROM marketplace_product_variants),
    'totalOrders', (SELECT COUNT(*) FROM marketplace_orders),
    'totalRevenue', COALESCE((
      SELECT SUM(total_amount) FROM marketplace_orders
      WHERE status IN ('completed', 'delivered')
    ), 0),
    'pendingOrders', (SELECT COUNT(*) FROM marketplace_orders WHERE status = 'pending'),
    'activeVariants', (SELECT COUNT(*) FROM marketplace_product_variants WHERE is_active),
    'inactiveVariants', (SELECT COUNT(*) FROM marketplace_product_variants WHERE NOT is_active),
    'unmappedVariants', (
      SELECT COUNT(*) FROM marketplace_product_variants v
      WHERE NOT EXISTS (
        SELECT 1 FROM marketplace_provider_mapping m WHERE m.variant_id = v.id
      )
    ),
    'activeCoupons', (SELECT COUNT(*) FROM marketplace_coupons WHERE is_active)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ── RPC: admin analytics ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_marketplace_analytics(
  p_period TEXT DEFAULT 'daily'
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_interval INTERVAL;
  v_since TIMESTAMPTZ;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden');
  END IF;

  v_interval := CASE p_period
    WHEN 'weekly' THEN INTERVAL '7 days'
    WHEN 'monthly' THEN INTERVAL '30 days'
    ELSE INTERVAL '1 day'
  END;
  v_since := now() - v_interval;

  RETURN jsonb_build_object(
    'success', true,
    'period', p_period,
    'revenue', COALESCE((
      SELECT SUM(total_amount) FROM marketplace_orders
      WHERE created_at >= v_since AND status IN ('completed', 'delivered')
    ), 0),
    'orderCount', (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since),
    'failedOrders', (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since AND status = 'failed'),
    'refundedOrders', (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since AND status = 'refunded'),
    'walletPayments', (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since AND payment_method = 'wallet'),
    'kspPayments', (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since AND payment_method = 'ksp'),
    'averageOrderValue', COALESCE((
      SELECT AVG(total_amount) FROM marketplace_orders
      WHERE created_at >= v_since AND status IN ('completed', 'delivered')
    ), 0),
    'conversionRate', CASE
      WHEN (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since) = 0 THEN 0
      ELSE ROUND(
        100.0 * (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since AND status IN ('completed', 'delivered'))
        / (SELECT COUNT(*) FROM marketplace_orders WHERE created_at >= v_since), 2
      )
    END,
    'topProducts', COALESCE((
      SELECT jsonb_agg(row_to_json(t))
      FROM (
        SELECT oi.product_name_en AS name, oi.product_id AS id, SUM(oi.total_price) AS value
        FROM marketplace_order_items oi
        JOIN marketplace_orders o ON o.id = oi.order_id
        WHERE o.created_at >= v_since AND o.status IN ('completed', 'delivered')
        GROUP BY oi.product_id, oi.product_name_en
        ORDER BY value DESC
        LIMIT 10
      ) t
    ), '[]'::jsonb),
    'topCategories', COALESCE((
      SELECT jsonb_agg(row_to_json(t))
      FROM (
        SELECT oi.brand_name_en AS name, oi.brand_id AS id, SUM(oi.total_price) AS value
        FROM marketplace_order_items oi
        JOIN marketplace_orders o ON o.id = oi.order_id
        WHERE o.created_at >= v_since AND o.status IN ('completed', 'delivered')
        GROUP BY oi.brand_id, oi.brand_name_en
        ORDER BY value DESC
        LIMIT 10
      ) t
    ), '[]'::jsonb),
    'topBrands', COALESCE((
      SELECT jsonb_agg(row_to_json(t))
      FROM (
        SELECT oi.brand_name_en AS name, oi.brand_id AS id, COUNT(*) AS value
        FROM marketplace_order_items oi
        JOIN marketplace_orders o ON o.id = oi.order_id
        WHERE o.created_at >= v_since AND o.status IN ('completed', 'delivered')
        GROUP BY oi.brand_id, oi.brand_name_en
        ORDER BY value DESC
        LIMIT 10
      ) t
    ), '[]'::jsonb),
    'chartData', COALESCE((
      SELECT jsonb_agg(row_to_json(t) ORDER BY t.day)
      FROM (
        SELECT DATE(created_at) AS day,
               COUNT(*) AS orders,
               COALESCE(SUM(total_amount) FILTER (WHERE status IN ('completed', 'delivered')), 0) AS revenue
        FROM marketplace_orders
        WHERE created_at >= v_since
        GROUP BY DATE(created_at)
        ORDER BY day
      ) t
    ), '[]'::jsonb)
  );
END;
$$;

-- ── RPC: admin provider stats ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_marketplace_provider_stats()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_health RECORD;
  v_total_requests BIGINT;
  v_failed_requests BIGINT;
  v_daily_purchases BIGINT;
  v_monthly_purchases BIGINT;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden');
  END IF;

  SELECT * INTO v_health
  FROM marketplace_provider_health
  ORDER BY checked_at DESC
  LIMIT 1;

  SELECT COUNT(*), COUNT(*) FILTER (WHERE NOT success)
  INTO v_total_requests, v_failed_requests
  FROM marketplace_api_request_log
  WHERE created_at >= now() - INTERVAL '24 hours';

  SELECT COUNT(*) INTO v_daily_purchases
  FROM marketplace_orders
  WHERE created_at >= now() - INTERVAL '1 day'
    AND status IN ('completed', 'delivered', 'processing', 'providerAccepted');

  SELECT COUNT(*) INTO v_monthly_purchases
  FROM marketplace_orders
  WHERE created_at >= now() - INTERVAL '30 days'
    AND status IN ('completed', 'delivered', 'processing', 'providerAccepted');

  RETURN jsonb_build_object(
    'success', true,
    'oauthStatus', COALESCE(v_health.oauth_status, 'unknown'),
    'environment', COALESCE(v_health.environment, 'sandbox'),
    'apiLatencyMs', v_health.api_latency_ms,
    'catalogCount', COALESCE(v_health.catalog_count, 0),
    'balanceAmount', v_health.balance_amount,
    'balanceCurrency', v_health.balance_currency,
    'failedRequests', COALESCE(v_failed_requests, 0),
    'totalRequests24h', COALESCE(v_total_requests, 0),
    'successRate', CASE
      WHEN COALESCE(v_total_requests, 0) = 0 THEN 100
      ELSE ROUND(100.0 * (v_total_requests - v_failed_requests) / v_total_requests, 2)
    END,
    'dailyPurchases', v_daily_purchases,
    'monthlyPurchases', v_monthly_purchases,
    'lastCheckedAt', v_health.checked_at,
    'providerHealth', COALESCE(v_health.metadata->>'reloadlyStatus', 'unknown')
  );
END;
$$;

-- ── RPC: admin update order ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_admin_marketplace_update_order(
  p_order_id UUID,
  p_status TEXT DEFAULT NULL,
  p_payment_status TEXT DEFAULT NULL,
  p_delivery_status TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
BEGIN
  IF NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'Forbidden');
  END IF;

  SELECT * INTO v_order FROM marketplace_orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  UPDATE marketplace_orders SET
    status = COALESCE(p_status, status),
    payment_status = COALESCE(p_payment_status, payment_status),
    delivery_status = COALESCE(p_delivery_status, delivery_status),
    notes = COALESCE(p_notes, notes),
    timeline = CASE
      WHEN p_status IS NOT NULL THEN
        timeline || jsonb_build_array(
          jsonb_build_object('status', p_status, 'timestamp', now(), 'note', COALESCE(p_notes, 'Admin update'))
        )
      ELSE timeline
    END
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_admin_marketplace_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_marketplace_analytics TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_marketplace_provider_stats TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_admin_marketplace_update_order TO authenticated;
