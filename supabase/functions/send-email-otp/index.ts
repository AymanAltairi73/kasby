import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders, OTP_EXPIRY_SECONDS, VALID_PURPOSES } from "../_shared/otp/constants.ts"
import { createAdminClient, resolveUserIdFromJwt } from "../_shared/otp/supabase.ts"
import { isValidEmail, normalizeEmail } from "../_shared/otp/normalize.ts"
import { resolveUserId, provisionSignupUser } from "../_shared/otp/user-resolver.ts"
import { enforceSendRateLimit, expiresAt } from "../_shared/otp/security.ts"
import { insertOtpRecord, writeAuditLog } from "../_shared/otp/audit.ts"
import { sendEmailOtpDelivery } from "../_shared/otp/email-delivery.ts"
import { errorResponse, successResponse } from "../_shared/otp/response.ts"
import { logOtp } from "../_shared/otp/logger.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    if (!req.headers.get("apikey")) {
      return errorResponse("Unauthorized", 401, "UNAUTHORIZED")
    }

    const body = await req.json()
    const purpose = String(body.purpose ?? "verification")
    const email = normalizeEmail(String(body.email ?? body.destination ?? ""))
    const deviceFingerprint = req.headers.get("x-device-fingerprint") ??
      body.device_fingerprint ?? null
    const idempotencyKey = req.headers.get("x-idempotency-key") ??
      body.idempotency_key ?? null

    if (!email || !isValidEmail(email)) {
      return errorResponse("Invalid email address", 400, "INVALID_EMAIL")
    }
    if (!VALID_PURPOSES.has(purpose)) {
      return errorResponse("Invalid purpose", 400, "INVALID_PURPOSE")
    }

    const admin = createAdminClient()
    const authUserId = await resolveUserIdFromJwt(admin, req.headers.get("Authorization"))

    let userId = await resolveUserId(admin, email, "email", purpose, authUserId)

    if (!userId && purpose === "signup" && body.provision_password) {
      userId = await provisionSignupUser(
        admin,
        email,
        String(body.provision_password),
        body.provision_metadata ?? {},
      )
    }

    if (!userId && purpose === "password_reset") {
      await writeAuditLog(admin, {
        action: "send",
        destinationType: "email",
        destination: email,
        purpose,
        status: "generic_success",
        deviceFingerprint,
        idempotencyKey,
      })
      return successResponse({
        delivery: "email",
        expires_in_seconds: OTP_EXPIRY_SECONDS,
        message: "If this account exists, an OTP has been sent.",
      })
    }

    if (!userId) {
      return errorResponse("User not found", 404, "USER_NOT_FOUND")
    }

    const rate = await enforceSendRateLimit(admin, userId, email)
    if (!rate.allowed) {
      return errorResponse(rate.message!, 429, rate.code)
    }

    const delivery = await sendEmailOtpDelivery(email, purpose)

    const otpId = await insertOtpRecord(admin, {
      user_id: userId,
      destination: email,
      destination_type: "email",
      purpose,
      provider: delivery.provider,
      twilio_verification_sid: delivery.twilioSid ?? null,
      otp_hash: delivery.otpHash ?? null,
      idempotency_key: idempotencyKey,
      device_fingerprint: deviceFingerprint,
      expires_at: expiresAt(),
      attempts: 0,
      max_attempts: 5,
      is_used: false,
    })

    await writeAuditLog(admin, {
      otpVerificationId: otpId,
      userId,
      action: "send",
      destinationType: "email",
      destination: email,
      purpose,
      provider: delivery.provider,
      status: "sent",
      httpStatus: 200,
      deviceFingerprint,
      idempotencyKey,
    })

    return successResponse({
      delivery: delivery.provider === "twilio" ? "twilio_email" : "resend_email",
      expires_in_seconds: OTP_EXPIRY_SECONDS,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal Error"
    logOtp("error", "SEND_EMAIL", { source: "send-email-otp", message })
    return errorResponse(message, 500, "INTERNAL_ERROR")
  }
})
