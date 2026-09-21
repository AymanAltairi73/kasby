-- Allow multi-angle selfie document types used by the KYC flow.
ALTER TABLE public.kyc_documents
  DROP CONSTRAINT IF EXISTS kyc_documents_document_type_check;

ALTER TABLE public.kyc_documents
  ADD CONSTRAINT kyc_documents_document_type_check
  CHECK (
    document_type = ANY (
      ARRAY[
        'id_card_front'::text,
        'id_card_back'::text,
        'passport'::text,
        'selfie'::text,
        'selfie_front'::text,
        'selfie_right'::text,
        'selfie_left'::text,
        'proof_of_address'::text,
        'other'::text
      ]
    )
  );

COMMENT ON COLUMN public.kyc_documents.metadata IS
  'Optional JSON metadata for liveness/selfie capture (yaw angles, device, session).';
