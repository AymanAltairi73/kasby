-- Twilio Verify OTP platform: schema alignment + audit logs

-- Align otp_verifications with unified destination model
ALTER TABLE public.otp_verifications
  ADD COLUMN IF NOT EXISTS destination text,
  ADD COLUMN IF NOT EXISTS destination_type text,
  ADD COLUMN IF NOT EXISTS otp_hash text,
  ADD COLUMN IF NOT EXISTS purpose text,
  ADD COLUMN IF NOT EXISTS provider text DEFAULT 'local',
  ADD COLUMN IF NOT EXISTS twilio_verification_sid text,
  ADD COLUMN IF NOT EXISTS idempotency_key text,
  ADD COLUMN IF NOT EXISTS device_fingerprint text;

UPDATE public.otp_verifications
SET
  destination = COALESCE(destination, target),
  destination_type = COALESCE(destination_type, target_type),
  otp_hash = COALESCE(otp_hash, code_hash),
  purpose = COALESCE(purpose, type)
WHERE destination IS NULL
   OR destination_type IS NULL
   OR otp_hash IS NULL
   OR purpose IS NULL;

CREATE INDEX IF NOT EXISTS idx_otp_verifications_destination_purpose
  ON public.otp_verifications (destination, purpose, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_otp_verifications_user_purpose
  ON public.otp_verifications (user_id, purpose, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_otp_verifications_idempotency
  ON public.otp_verifications (idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_otp_verifications_expires_active
  ON public.otp_verifications (expires_at)
  WHERE verified_at IS NULL AND used_at IS NULL;

-- Audit trail for OTP send/verify events
CREATE TABLE IF NOT EXISTS public.otp_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  otp_verification_id uuid REFERENCES public.otp_verifications(id) ON DELETE SET NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  destination_type text NOT NULL,
  destination_masked text NOT NULL,
  purpose text NOT NULL,
  provider text,
  status text NOT NULL,
  http_status integer,
  error_message text,
  device_fingerprint text,
  idempotency_key text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_audit_logs_user_created
  ON public.otp_audit_logs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_otp_audit_logs_purpose_created
  ON public.otp_audit_logs (purpose, created_at DESC);

ALTER TABLE public.otp_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Service role access otp_audit_logs" ON public.otp_audit_logs;
CREATE POLICY "Service role access otp_audit_logs"
  ON public.otp_audit_logs
  FOR ALL
  USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "Users can view their own OTP audit logs" ON public.otp_audit_logs;
CREATE POLICY "Users can view their own OTP audit logs"
  ON public.otp_audit_logs
  FOR SELECT
  USING (auth.uid() = user_id);

COMMENT ON TABLE public.otp_audit_logs IS 'Structured audit trail for Twilio/Resend OTP send and verify events';
