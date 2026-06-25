import { logOtp } from "./logger.ts"
import { isTwilioConfigured, isTwilioVerifyError, twilioStartVerification } from "./twilio.ts"
import { generateOtpCode, hashOtp } from "./security.ts"
import { OTP_EXPIRY_SECONDS } from "./constants.ts"

const DEFAULT_FROM = "Kasby <onboarding@kasby.resend.com>"

export type EmailSendResult = {
  provider: "twilio" | "resend"
  twilioSid?: string
  otpCode?: string
  otpHash?: string
}

export async function sendEmailOtpDelivery(
  email: string,
  purpose: string,
): Promise<EmailSendResult> {
  const flow = purpose.toUpperCase()

  if (isTwilioConfigured()) {
    try {
      const result = await twilioStartVerification(email, "email", purpose)
      return { provider: "twilio", twilioSid: result.sid }
    } catch (err) {
      if (isTwilioVerifyError(err) && err.code === "TWILIO_EMAIL_NOT_CONFIGURED") {
        logOtp("info", flow, {
          source: "Twilio",
          twilio_code: err.twilioCode,
          message: "Email channel unavailable — falling back to Resend",
        })
      } else {
        throw err
      }
    }
  }

  return await sendViaResend(email, purpose)
}

async function sendViaResend(email: string, purpose: string): Promise<EmailSendResult> {
  const apiKey = Deno.env.get("RESEND_API_KEY")
  const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ?? DEFAULT_FROM
  const flow = purpose.toUpperCase()

  if (!apiKey) {
    throw new Error("RESEND_API_KEY is not configured")
  }

  const otpCode = generateOtpCode()
  const otpHash = await hashOtp(otpCode)

  const subject = purpose === "signup"
    ? "رمز تأكيد حسابك في كاسبي"
    : purpose === "password_reset"
    ? "رمز إعادة تعيين كلمة المرور - كاسبي"
    : "رمز التحقق - كاسبي"

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [email],
      subject,
      html: `
        <div dir="rtl" style="font-family: Arial, sans-serif; padding: 24px;">
          <h2>كاسبي</h2>
          <p>رمز التحقق الخاص بك هو:</p>
          <p style="font-size: 32px; font-weight: bold; letter-spacing: 6px;">${otpCode}</p>
          <p>ينتهي خلال ${OTP_EXPIRY_SECONDS / 60} دقائق.</p>
        </div>
      `,
    }),
  })

  if (!response.ok) {
    const body = await response.text()
    logOtp("error", flow, { source: "Resend", status: response.status, message: body })
    throw new Error(`Resend delivery failed: ${body}`)
  }

  logOtp("info", flow, { source: "Resend", status: response.status, message: "sent" })
  return { provider: "resend", otpCode, otpHash }
}

export async function verifyEmailOtpDelivery(
  email: string,
  code: string,
  purpose: string,
  record?: { provider?: string | null; otp_hash?: string | null; id?: string },
): Promise<{ valid: boolean; provider: string }> {
  if (record?.provider === "twilio" || (!record?.otp_hash && isTwilioConfigured())) {
    const { twilioCheckVerification } = await import("./twilio.ts")
    const result = await twilioCheckVerification(email, code, purpose)
    return { valid: result.valid, provider: "twilio" }
  }

  if (!record?.otp_hash) {
    return { valid: false, provider: "resend" }
  }

  const provided = await hashOtp(code.replace(/\D/g, ""))
  return { valid: provided === record.otp_hash, provider: "resend" }
}
