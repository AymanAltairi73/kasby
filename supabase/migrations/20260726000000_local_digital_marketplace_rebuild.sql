-- ── Kasby Local Digital Marketplace Schema & Purchase Engine ───────────────────────

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop legacy marketplace tables if they exist to prevent column mismatch errors (e.g., is_visible vs is_active)
DROP TABLE IF EXISTS public.marketplace_banners CASCADE;
DROP TABLE IF EXISTS public.marketplace_orders CASCADE;
DROP TABLE IF EXISTS public.marketplace_digital_codes CASCADE;
DROP TABLE IF EXISTS public.marketplace_products CASCADE;
DROP TABLE IF EXISTS public.marketplace_categories CASCADE;

-- 1. Categories
CREATE TABLE IF NOT EXISTS public.marketplace_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  icon_name TEXT DEFAULT 'category',
  image_url TEXT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Products
CREATE TABLE IF NOT EXISTS public.marketplace_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID NOT NULL REFERENCES public.marketplace_categories(id) ON DELETE CASCADE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  description_ar TEXT DEFAULT '',
  description_en TEXT DEFAULT '',
  image_url TEXT,
  wallet_price NUMERIC(12, 2) NOT NULL CHECK (wallet_price >= 0),
  ksp_price NUMERIC(12, 2) CHECK (ksp_price IS NULL OR ksp_price >= 0),
  original_price NUMERIC(12, 2),
  discount_percent INT DEFAULT 0 CHECK (discount_percent >= 0 AND discount_percent <= 100),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured BOOLEAN NOT NULL DEFAULT FALSE,
  is_top_selling BOOLEAN NOT NULL DEFAULT FALSE,
  is_new BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Digital Codes Inventory
CREATE TABLE IF NOT EXISTS public.marketplace_digital_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.marketplace_products(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  serial_number TEXT,
  is_used BOOLEAN NOT NULL DEFAULT FALSE,
  used_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  used_at TIMESTAMPTZ,
  order_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_digital_codes_product_stock 
  ON public.marketplace_digital_codes (product_id, is_used) WHERE is_used = FALSE;

-- 4. Orders
CREATE TABLE IF NOT EXISTS public.marketplace_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number TEXT NOT NULL UNIQUE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id UUID REFERENCES public.marketplace_products(id) ON DELETE SET NULL,
  product_name_ar TEXT NOT NULL,
  product_name_en TEXT NOT NULL,
  product_image_url TEXT,
  amount NUMERIC(12, 2) NOT NULL,
  payment_method TEXT NOT NULL CHECK (payment_method IN ('wallet', 'ksp')),
  status TEXT NOT NULL DEFAULT 'completed',
  delivery_code TEXT NOT NULL,
  serial_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_user_date 
  ON public.marketplace_orders (user_id, created_at DESC);

-- 5. Banners
CREATE TABLE IF NOT EXISTS public.marketplace_banners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_ar TEXT,
  title_en TEXT,
  image_url TEXT NOT NULL,
  action_url TEXT,
  target_category_id UUID REFERENCES public.marketplace_categories(id) ON DELETE SET NULL,
  target_product_id UUID REFERENCES public.marketplace_products(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS Enablement
ALTER TABLE public.marketplace_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_digital_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_banners ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS public_categories_read ON public.marketplace_categories;
CREATE POLICY public_categories_read ON public.marketplace_categories FOR SELECT TO authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS public_products_read ON public.marketplace_products;
CREATE POLICY public_products_read ON public.marketplace_products FOR SELECT TO authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS public_banners_read ON public.marketplace_banners;
CREATE POLICY public_banners_read ON public.marketplace_banners FOR SELECT TO authenticated USING (is_active = TRUE);

DROP POLICY IF EXISTS user_orders_own ON public.marketplace_orders;
CREATE POLICY user_orders_own ON public.marketplace_orders FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Admin RLS Policies (Allow full access for admin panel / service role)
DROP POLICY IF EXISTS admin_all_categories ON public.marketplace_categories;
CREATE POLICY admin_all_categories ON public.marketplace_categories FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS admin_all_products ON public.marketplace_products;
CREATE POLICY admin_all_products ON public.marketplace_products FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS admin_all_codes ON public.marketplace_digital_codes;
CREATE POLICY admin_all_codes ON public.marketplace_digital_codes FOR ALL TO authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS admin_all_banners ON public.marketplace_banners;
CREATE POLICY admin_all_banners ON public.marketplace_banners FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ── Atomic Purchase RPC Function ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_marketplace_buy_product(
  p_product_id UUID,
  p_payment_method TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_product RECORD;
  v_code_rec RECORD;
  v_wallet_id UUID;
  v_avail_bal NUMERIC(18, 4);
  v_ksp_bal INT;
  v_frozen BOOLEAN;
  v_new_bal NUMERIC(18, 4);
  v_order_id UUID := gen_random_uuid();
  v_order_num TEXT;
  v_paid_amount NUMERIC(12, 2);
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthorized', 'message_ar', 'يجب تسجيل الدخول أولاً');
  END IF;

  IF p_payment_method NOT IN ('wallet', 'ksp') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_method', 'message_ar', 'طريقة الدفع غير صالحة');
  END IF;

  -- 1. Get & Lock Product
  SELECT * INTO v_product FROM marketplace_products WHERE id = p_product_id AND is_active = TRUE;
  IF v_product.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'product_not_found', 'message_ar', 'المنتج غير موجود أو غير متاح حالياً');
  END IF;

  -- 2. Lock & Select Available Code
  SELECT id, code, serial_number INTO v_code_rec 
  FROM marketplace_digital_codes 
  WHERE product_id = p_product_id AND is_used = FALSE 
  ORDER BY created_at ASC 
  LIMIT 1 FOR UPDATE SKIP LOCKED;

  IF v_code_rec.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'out_of_stock', 'message_ar', 'عذراً، نفد مخزون الأكواد لهذا المنتج حالياً');
  END IF;

  -- 3. Process Payment
  IF p_payment_method = 'wallet' THEN
    SELECT id, available_balance, is_frozen INTO v_wallet_id, v_avail_bal, v_frozen
    FROM wallets WHERE user_id = v_user_id FOR UPDATE;

    IF v_wallet_id IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found', 'message_ar', 'لم يتم العثور على محفظة للمستخدم');
    END IF;

    IF v_frozen = TRUE THEN
      RETURN jsonb_build_object('success', false, 'error', 'wallet_frozen', 'message_ar', 'محفظتك مجمدة، يرجى التواصل مع الدعم');
    END IF;

    IF v_avail_bal < v_product.wallet_price THEN
      RETURN jsonb_build_object('success', false, 'error', 'insufficient_wallet_balance', 'message_ar', 'رصيد المحفظة بالدولار غير كافٍ لإتمام الشراء');
    END IF;

    -- Deduct Balance
    v_new_bal := v_avail_bal - v_product.wallet_price;
    UPDATE wallets SET available_balance = v_new_bal WHERE id = v_wallet_id;

    -- Log Transaction
    INSERT INTO transactions (
      user_id, wallet_id, type, amount, fee, currency, status,
      running_balance, description, idempotency_key, reference_id
    ) VALUES (
      v_user_id, v_wallet_id, 'marketplace_purchase', v_product.wallet_price, 0, 'USD', 'completed',
      v_new_bal, 'شراء من متجر كاسبي: ' || v_product.name_ar, gen_random_uuid()::text, v_order_id::text
    );

    v_paid_amount := v_product.wallet_price;

  ELSIF p_payment_method = 'ksp' THEN
    IF v_product.ksp_price IS NULL OR v_product.ksp_price <= 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'ksp_not_supported', 'message_ar', 'هذا المنتج لا يدعم الشراء برصيد KSP');
    END IF;

    PERFORM ensure_user_points(v_user_id);

    SELECT current_balance INTO v_ksp_bal
    FROM user_points WHERE user_id = v_user_id FOR UPDATE;

    IF v_ksp_bal IS NULL OR v_ksp_bal < v_product.ksp_price THEN
      RETURN jsonb_build_object('success', false, 'error', 'insufficient_ksp_balance', 'message_ar', 'رصيد KSP غير كافٍ لإتمام الشراء');
    END IF;

    -- Deduct KSP Points
    UPDATE user_points 
    SET current_balance = current_balance - v_product.ksp_price,
        total_spent = total_spent + v_product.ksp_price,
        updated_at = now()
    WHERE user_id = v_user_id;

    -- Log Point History
    INSERT INTO point_history (user_id, points, type, description, reference_id)
    VALUES (v_user_id, -v_product.ksp_price, 'spend', 'شراء من متجر كاسبي (KSP): ' || v_product.name_ar, v_order_id::text);

    v_paid_amount := v_product.ksp_price;
  END IF;

  -- 4. Generate Order Number
  v_order_num := 'KSB-' || to_char(now(), 'YYMMDD') || '-' || upper(substring(gen_random_uuid()::text from 1 for 6));

  -- 5. Create Order Record
  INSERT INTO marketplace_orders (
    id, order_number, user_id, product_id, product_name_ar, product_name_en,
    product_image_url, amount, payment_method, status, delivery_code, serial_number
  ) VALUES (
    v_order_id, v_order_num, v_user_id, p_product_id, v_product.name_ar, v_product.name_en,
    v_product.image_url, v_paid_amount, p_payment_method, 'completed', v_code_rec.code, v_code_rec.serial_number
  );

  -- 6. Mark Code as Used
  UPDATE marketplace_digital_codes 
  SET is_used = TRUE, used_by_user_id = v_user_id, used_at = now(), order_id = v_order_id 
  WHERE id = v_code_rec.id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'order_number', v_order_num,
    'delivery_code', v_code_rec.code,
    'serial_number', v_code_rec.serial_number,
    'paid_amount', v_paid_amount,
    'payment_method', p_payment_method
  );
END;
$$;

-- Seed Default Categories if Empty
INSERT INTO public.marketplace_categories (slug, name_ar, name_en, icon_name, sort_order)
VALUES 
  ('games', 'الألعاب', 'Games', 'sports_esports', 1),
  ('gift-cards', 'بطاقات الهدايا', 'Gift Cards', 'card_giftcard', 2),
  ('subscriptions', 'الاشتراكات', 'Subscriptions', 'subscriptions', 3),
  ('e-wallets', 'المحافظ الإلكترونية', 'E-Wallets', 'account_balance_wallet', 4),
  ('apps', 'التطبيقات', 'Apps', 'apps', 5),
  ('internet', 'الإنترنت', 'Internet', 'wifi', 6),
  ('offers', 'العروض الخاصة', 'Special Offers', 'local_offer', 7)
ON CONFLICT (slug) DO NOTHING;
