import {
  COOLDOWN_SECONDS,
  MAX_SENDS_PER_WINDOW,
  OTP_EXPIRY_MINUTES,
  RATE_LIMIT_WINDOW_MINUTES,
} from "./constants.ts"

export async function enforceSendRateLimit(
  admin: ReturnType<typeof import("./supabase.ts").createAdminClient>,
  userId: string | null,
  destination: string,
): Promise<{ allowed: boolean; code?: string; message?: string }> {
  const windowStart = new Date(Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60_000)
    .toISOString()

  let query = admin.from("otp_verifications").select("created_at").gte(
    "created_at",
    windowStart,
  )
  if (userId) {
    query = query.eq("user_id", userId)
  } else {
    query = query.eq("destination", destination)
  }

  const { data: recent } = await query
  const rows = recent ?? []

  if (rows.length >= MAX_SENDS_PER_WINDOW) {
    return {
      allowed: false,
      code: "RATE_LIMIT_EXCEEDED",
      message: `Too many requests. Wait ${RATE_LIMIT_WINDOW_MINUTES} minutes.`,
    }
  }

  const last = rows[rows.length - 1]
  if (last && new Date(last.created_at).getTime() > Date.now() - COOLDOWN_SECONDS * 1000) {
    return {
      allowed: false,
      code: "COOLDOWN_ACTIVE",
      message: `Please wait ${COOLDOWN_SECONDS} seconds before resending.`,
    }
  }

  return { allowed: true }
}

export function expiresAt(): string {
  return new Date(Date.now() + OTP_EXPIRY_MINUTES * 60_000).toISOString()
}

export async function hashOtp(code: string): Promise<string> {
  const bytes = new TextEncoder().encode(code)
  const digest = await crypto.subtle.digest("SHA-256", bytes)
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0"))
    .join("")
}

export function generateOtpCode(): string {
  const randomBytes = new Uint32Array(1)
  crypto.getRandomValues(randomBytes)
  return (100000 + (randomBytes[0] % 900000)).toString()
}
