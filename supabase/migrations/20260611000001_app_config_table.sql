-- Remote app configuration (version gate, loan interest rate, etc.)

CREATE TABLE IF NOT EXISTS public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL,
  description text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_config_read_authenticated" ON public.app_config;
CREATE POLICY "app_config_read_authenticated"
  ON public.app_config FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "app_config_read_anon" ON public.app_config;
CREATE POLICY "app_config_read_anon"
  ON public.app_config FOR SELECT TO anon
  USING (true);

GRANT SELECT ON public.app_config TO anon, authenticated;

INSERT INTO public.app_config (key, value, description) VALUES
  ('min_app_version', '1.0.0', 'Minimum required mobile app version (semver)'),
  ('loan_interest_rate', '0.10', 'Default loan interest rate (decimal)')
ON CONFLICT (key) DO UPDATE SET
  value = EXCLUDED.value,
  description = EXCLUDED.description,
  updated_at = now();
