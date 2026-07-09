-- Multi-angle KYC selfie metadata support
ALTER TABLE public.kyc_documents
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.kyc_documents.metadata IS
  'Optional capture metadata (liveness session, device info, yaw angles).';
