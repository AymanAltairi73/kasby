-- Fix category seed when marketplace_categories.id is UUID (legacy schema).
-- Safe to run multiple times.

ALTER TABLE public.marketplace_categories
  ADD COLUMN IF NOT EXISTS slug TEXT,
  ADD COLUMN IF NOT EXISTS name_en TEXT,
  ADD COLUMN IF NOT EXISTS name_ar TEXT,
  ADD COLUMN IF NOT EXISTS icon_name TEXT DEFAULT 'category',
  ADD COLUMN IF NOT EXISTS sort_order INT DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_visible BOOLEAN DEFAULT true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_marketplace_categories_slug
  ON public.marketplace_categories (slug)
  WHERE slug IS NOT NULL;

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
