import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import { maskDestination } from "./logger.ts"

export async function writeAuditLog(
  admin: SupabaseClient,
  entry: {
    otpVerificationId?: string | null
    userId?: string | null
    action: string
    destinationType: "email" | "phone"
    destination: string
    purpose: string
    provider?: string
    status: string
    httpStatus?: number
    errorMessage?: string
    deviceFingerprint?: string | null
    idempotencyKey?: string | null
    metadata?: Record<string, unknown>
  },
): Promise<void> {
  await admin.from("otp_audit_logs").insert({
    otp_verification_id: entry.otpVerificationId ?? null,
    user_id: entry.userId ?? null,
    action: entry.action,
    destination_type: entry.destinationType,
    destination_masked: maskDestination(entry.destination, entry.destinationType),
    purpose: entry.purpose,
    provider: entry.provider ?? null,
    status: entry.status,
    http_status: entry.httpStatus ?? null,
    error_message: entry.errorMessage ?? null,
    device_fingerprint: entry.deviceFingerprint ?? null,
    idempotency_key: entry.idempotencyKey ?? null,
    metadata: entry.metadata ?? {},
  })
}

export async function insertOtpRecord(
  admin: SupabaseClient,
  record: Record<string, unknown>,
): Promise<string | null> {
  const payload = {
    ...record,
    target: record.destination,
    target_type: record.destination_type,
    code_hash: record.otp_hash ?? record.code_hash,
    type: record.purpose,
  }
  const { data, error } = await admin.from("otp_verifications").insert(payload).select("id")
    .single()
  if (error) throw error
  return data?.id ?? null
}

export async function markOtpVerified(
  admin: SupabaseClient,
  otpId: string,
): Promise<void> {
  const now = new Date().toISOString()
  await admin.from("otp_verifications").update({
    verified_at: now,
    used_at: now,
    is_used: true,
  }).eq("id", otpId)
}
