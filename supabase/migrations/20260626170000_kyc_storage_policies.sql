-- KYC & deposit document storage policies for the `documents` bucket

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'documents',
  'documents',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Users upload KYC files under kyc/{user_id}/
DROP POLICY IF EXISTS "Users upload own kyc files" ON storage.objects;
CREATE POLICY "Users upload own kyc files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = 'kyc'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users read own kyc files" ON storage.objects;
CREATE POLICY "Users read own kyc files"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = 'kyc'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users update own kyc files" ON storage.objects;
CREATE POLICY "Users update own kyc files"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = 'kyc'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- Users upload deposit proofs under deposits/{user_id}/
DROP POLICY IF EXISTS "Users upload own deposit proofs" ON storage.objects;
CREATE POLICY "Users upload own deposit proofs"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = 'deposits'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

DROP POLICY IF EXISTS "Users read own deposit proofs" ON storage.objects;
CREATE POLICY "Users read own deposit proofs"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documents'
  AND (storage.foldername(name))[1] = 'deposits'
  AND (storage.foldername(name))[2] = auth.uid()::text
);

-- Admins read all documents in bucket
DROP POLICY IF EXISTS "Admins read all documents" ON storage.objects;
CREATE POLICY "Admins read all documents"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documents'
  AND public.is_admin()
);
