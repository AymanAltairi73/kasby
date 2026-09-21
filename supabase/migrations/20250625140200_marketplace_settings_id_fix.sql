-- Fix marketplace_settings seed when id column is INTEGER (legacy schema).
-- Safe to run multiple times.

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
  IF EXISTS (SELECT 1 FROM public.marketplace_settings LIMIT 1) THEN
    RETURN;
  END IF;

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
  ELSIF v_id_type IN ('text', 'varchar', 'bpchar') THEN
    INSERT INTO public.marketplace_settings (id) VALUES ('default');
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;
