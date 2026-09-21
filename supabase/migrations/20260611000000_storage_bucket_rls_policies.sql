-- Ensure storage buckets exist (policies are managed via Supabase dashboard / postgres migrations).
-- NOTE: Do NOT run ALTER TABLE on storage.objects — it is owned by supabase_storage_admin.
-- Existing production policies already cover documents and chat_attachments buckets.

INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public)
VALUES ('chat_attachments', 'chat_attachments', false)
ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;
