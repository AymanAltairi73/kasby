import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders, OTP_EXPIRY_SECONDS, VALID_PURPOSES } from "../_shared/otp/constants.ts"
import { createAdminClient, resolveUserIdFromJwt } from "../_shared/otp/supabase.ts"
import { isValidE164, normalizePhoneE164 } from "../_shared/otp/normalize.ts"
import { resolveUserId } from "../_shared/otp/user-resolver.ts"
import { enforceSendRateLimit, expiresAt } from "../_shared/otp/security.ts"
import { insertOtpRecord, writeAuditLog } from "../_shared/otp/audit.ts"
import { isTwilioConfigured, isTwilioVerifyError, twilioStartVerification } from "../_shared/otp/twilio.ts"
import { errorResponse, successResponse } from "../_shared/otp/response.ts"
import { logOtp } from "../_shared/otp/logger.ts"

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    if (!req.headers.get("apikey")) {
      return errorResponse("Unauthorized", 401, "UNAUTHORIZED")
    }

    if (!isTwilioConfigured()) {
      return errorResponse("Twilio Verify is not configured", 503, "TWILIO_NOT_CONFIGURED")
    }

    const body = await req.json()
    const purpose = String(body.purpose ?? "verification")
    const phone = normalizePhoneE164(String(body.phone ?? body.destination ?? ""))
    const deviceFingerprint = req.headers.get("x-device-fingerprint") ??
      body.device_fingerprint ?? null
    const idempotencyKey = req.headers.get("x-idempotency-key") ??
      body.idempotency_key ?? null

    if (!phone || !isValidE164(phone)) {
      return errorResponse("Invalid phone number. Use E.164 format.", 400, "INVALID_PHONE")
    }
    if (!VALID_PURPOSES.has(purpose)) {
      return errorResponse("Invalid purpose", 400, "INVALID_PURPOSE")
    }

    const admin = createAdminClient()
    const authUserId = await resolveUserIdFromJwt(admin, req.headers.get("Authorization"))

    let userId = await resolveUserId(admin, phone, "phone", purpose, authUserId)

    if (!userId && purpose === "password_reset") {
      await writeAuditLog(admin, {
        action: "send",
        destinationType: "phone",
        destination: phone,
        purpose,
        provider: "twilio",
        status: "generic_success",
        deviceFingerprint,
        idempotencyKey,
      })
      return successResponse({
        delivery: "twilio_sms",
        expires_in_seconds: OTP_EXPIRY_SECONDS,
        message: "If this account exists, an OTP has been sent.",
      })
    }

    if (!userId) {
      return errorResponse("User not found", 404, "USER_NOT_FOUND")
    }

    const rate = await enforceSendRateLimit(admin, userId, phone)
    if (!rate.allowed) {
      return errorResponse(rate.message!, 429, rate.code)
    }

    const twilio = await twilioStartVerification(phone, "sms", purpose)

    const otpId = await insertOtpRecord(admin, {
      user_id: userId,
      destination: phone,
      destination_type: "phone",
      purpose,
      provider: "twilio",
      twilio_verification_sid: twilio.sid,
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
      destinationType: "phone",
      destination: phone,
      purpose,
      provider: "twilio",
      status: "sent",
      httpStatus: 200,
      deviceFingerprint,
      idempotencyKey,
      metadata: { twilio_sid: twilio.sid },
    })

    logOtp("info", purpose.toUpperCase(), {
      source: "send-phone-otp",
      status: 200,
      delivery: "twilio_sms",
    })

    return successResponse({
      delivery: "twilio_sms",
      expires_in_seconds: OTP_EXPIRY_SECONDS,
    })
  } catch (err) {
    if (isTwilioVerifyError(err)) {
      logOtp("error", "SEND_PHONE", {
        source: "send-phone-otp",
        code: err.code,
        twilio_code: err.twilioCode,
        message: err.message,
      })
      return errorResponse(err.message, err.httpStatus, err.code)
    }
    const message = err instanceof Error ? err.message : "Internal Error"
    logOtp("error", "SEND_PHONE", { source: "send-phone-otp", message })
    return errorResponse(message, 500, "INTERNAL_ERROR")
  }
})
