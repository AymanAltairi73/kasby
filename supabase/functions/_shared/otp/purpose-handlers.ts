import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"
import { MAX_ATTEMPTS } from "./constants.ts"
import { normalizeEmail, normalizePhoneE164, phoneLookupVariants } from "./normalize.ts"

export async function applyPurposeSideEffects(
  admin: SupabaseClient,
  params: {
    userId: string
    purpose: string
    destinationType: "email" | "phone"
    destination: string
    newValue?: string
    newPassword?: string
  },
): Promise<void> {
  const { userId, purpose, destinationType, destination, newValue, newPassword } = params

  switch (purpose) {
    case "signup": {
      if (destinationType === "email") {
        await admin.auth.admin.updateUserById(userId, { email_confirm: true })
        await admin.from("profiles").update({ email: normalizeEmail(destination) }).eq("id", userId)
      } else {
        const phone = normalizePhoneE164(destination)
        await admin.auth.admin.updateUserById(userId, { phone, phone_confirm: true })
        await admin.from("profiles").update({ phone }).eq("id", userId)
      }
      break
    }
    case "password_reset": {
      if (newPassword) {
        await admin.auth.admin.updateUserById(userId, { password: newPassword })
      }
      break
    }
    case "email_change": {
      const email = normalizeEmail(newValue ?? destination)
      await admin.auth.admin.updateUserById(userId, { email, email_confirm: true })
      await admin.from("profiles").update({ email }).eq("id", userId)
      break
    }
    case "phone_change": {
      const phone = normalizePhoneE164(newValue ?? destination)
      await admin.auth.admin.updateUserById(userId, { phone, phone_confirm: true })
      await admin.from("profiles").update({ phone }).eq("id", userId)
      break
    }
    case "verification":
    case "login":
    case "sensitive_action":
      break
    default:
      break
  }
}

export async function findActiveOtpRecord(
  admin: SupabaseClient,
  destination: string,
  destinationType: string,
  purpose: string,
) {
  const variants = destinationType === "phone"
    ? phoneLookupVariants(destination)
    : [normalizeEmail(destination)]

  for (const variant of variants) {
    const { data } = await admin.from("otp_verifications").select("*")
      .eq("destination", variant)
      .eq("destination_type", destinationType)
      .eq("purpose", purpose)
      .is("used_at", null)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle()
    if (data) return data

    const { data: legacy } = await admin.from("otp_verifications").select("*")
      .eq("target", variant)
      .eq("target_type", destinationType)
      .eq("type", purpose)
      .is("used_at", null)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle()
    if (legacy) return legacy
  }
  return null
}

export async function incrementAttempts(
  admin: SupabaseClient,
  otpId: string,
  currentAttempts: number,
): Promise<number> {
  const next = (currentAttempts ?? 0) + 1
  await admin.from("otp_verifications").update({ attempts: next }).eq("id", otpId)
  return next
}

export function attemptsExceeded(attempts: number | null | undefined): boolean {
  return (attempts ?? 0) >= MAX_ATTEMPTS
}
