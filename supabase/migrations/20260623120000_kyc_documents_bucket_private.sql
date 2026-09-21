-- Make KYC documents bucket private (production security remediation).
-- Signed URLs must be used for document access going forward.

UPDATE storage.buckets
SET public = false
WHERE id = 'documents';

-- Ensure authenticated users can read their own KYC folder objects via RLS (if not already).
-- Note: apply via Supabase CLI: supabase db push / migration apply
