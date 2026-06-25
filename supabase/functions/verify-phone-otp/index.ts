import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders, VALID_PURPOSES } from "../_shared/otp/constants.ts"
import { createAdminClient, resolveUserIdFromJwt } from "../_shared/otp/supabase.ts"
import { isValidE164, normalizePhoneE164 } from "../_shared/otp/normalize.ts"
import { resolveUserId } from "../_shared/otp/user-resolver.ts"
import { isTwilioConfigured, twilioCheckVerification } from "../_shared/otp/twilio.ts"
import {
  applyPurposeSideEffects,
  findActiveOtpRecord,
  incrementAttempts,
  attemptsExceeded,
} from "../_shared/otp/purpose-handlers.ts"
import { markOtpVerified, writeAuditLog } from "../_shared/otp/audit.ts"
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
    const code = String(body.code ?? body.otp_code ?? "").replace(/\D/g, "")

    if (!phone || !isValidE164(phone)) {
      return errorResponse("Invalid phone number", 400, "INVALID_PHONE")
    }
    if (code.length !== 6) {
      return errorResponse("Invalid OTP format", 400, "INVALID_OTP_FORMAT")
    }
    if (!VALID_PURPOSES.has(purpose)) {
      return errorResponse("Invalid purpose", 400, "INVALID_PURPOSE")
    }

    const admin = createAdminClient()
    const authUserId = await resolveUserIdFromJwt(admin, req.headers.get("Authorization"))
    const userId = await resolveUserId(admin, phone, "phone", purpose, authUserId)

    if (!userId && purpose !== "password_reset") {
      return errorResponse("User not found", 404, "USER_NOT_FOUND")
    }

    const record = userId
      ? await findActiveOtpRecord(admin, phone, "phone", purpose)
      : null

    if (record && attemptsExceeded(record.attempts)) {
      return errorResponse("Too many attempts", 403, "MAX_ATTEMPTS")
    }

    const twilio = await twilioCheckVerification(phone, code, purpose)
    if (twilio.error) {
      await writeAuditLog(admin, {
        otpVerificationId: record?.id,
        userId,
        action: "verify",
        destinationType: "phone",
        destination: phone,
        purpose,
        provider: "twilio",
        status: "failed",
        httpStatus: twilio.error.httpStatus,
        errorMessage: twilio.error.message,
        metadata: { twilio_code: twilio.error.twilioCode, code: twilio.error.code },
      })
      return errorResponse(twilio.error.message, twilio.error.httpStatus, twilio.error.code)
    }
    if (!twilio.valid) {
      if (record) {
        const attempts = await incrementAttempts(admin, record.id, record.attempts ?? 0)
        await writeAuditLog(admin, {
          otpVerificationId: record.id,
          userId,
          action: "verify",
          destinationType: "phone",
          destination: phone,
          purpose,
          provider: "twilio",
          status: "failed",
          httpStatus: 400,
          errorMessage: twilio.status,
        })
        return errorResponse("Invalid or expired OTP", 400, "INVALID_OTP", {
          remaining_attempts: Math.max(0, 5 - attempts),
        })
      }
      return errorResponse("Invalid or expired OTP", 400, "INVALID_OTP")
    }

    if (record) await markOtpVerified(admin, record.id)

    if (userId) {
      await applyPurposeSideEffects(admin, {
        userId,
        purpose,
        destinationType: "phone",
        destination: phone,
        newValue: body.new_value,
        newPassword: body.new_password,
      })
    }

    await writeAuditLog(admin, {
      otpVerificationId: record?.id,
      userId,
      action: "verify",
      destinationType: "phone",
      destination: phone,
      purpose,
      provider: "twilio",
      status: "verified",
      httpStatus: 200,
    })

    return successResponse({ verified: true, purpose })
  } catch (err) {
    const message = err instanceof Error ? err.message : "Internal Error"
    logOtp("error", "VERIFY_PHONE", { source: "verify-phone-otp", message })
    return errorResponse(message, 500, "INTERNAL_ERROR")
  }
})
