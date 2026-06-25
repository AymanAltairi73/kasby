export const OTP_LENGTH = 6
export const OTP_EXPIRY_MINUTES = 10
export const OTP_EXPIRY_SECONDS = OTP_EXPIRY_MINUTES * 60
export const MAX_ATTEMPTS = 5
export const COOLDOWN_SECONDS = 60
export const RATE_LIMIT_WINDOW_MINUTES = 15
export const MAX_SENDS_PER_WINDOW = 5

export const VALID_PURPOSES = new Set([
  "signup",
  "password_reset",
  "email_change",
  "phone_change",
  "sensitive_action",
  "verification",
  "login",
])

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-idempotency-key, x-device-fingerprint",
}
