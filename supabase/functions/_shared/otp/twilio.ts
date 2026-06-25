import { logOtp } from "./logger.ts"

type TwilioChannel = "sms" | "email"

/** Maps Twilio Verify error codes to Kasby API responses (see Twilio Verify v2 error docs). */
const TWILIO_VERIFY_ERRORS: Record<
  number,
  { code: string; httpStatus: number; message: string }
> = {
  60200: {
    code: "INVALID_PHONE",
    httpStatus: 400,
    message: "Invalid phone number format. Use E.164 format (e.g. +967...).",
  },
  60202: {
    code: "TWILIO_MAX_CHECK_ATTEMPTS",
    httpStatus: 429,
    message: "Too many incorrect attempts. Request a new code after it expires (10 minutes).",
  },
  60203: {
    code: "TWILIO_MAX_SEND_ATTEMPTS",
    httpStatus: 429,
    message: "Too many code requests. Wait 10 minutes before requesting another code.",
  },
  60205: {
    code: "UNSUPPORTED_PHONE",
    httpStatus: 400,
    message: "SMS verification is not supported for this phone number type.",
  },
  60212: {
    code: "TWILIO_CONCURRENT_REQUESTS",
    httpStatus: 429,
    message: "A verification is already in progress for this number. Please wait.",
  },
  60217: {
    code: "TWILIO_EMAIL_NOT_CONFIGURED",
    httpStatus: 503,
    message: "Twilio Verify email channel is not configured for this service.",
  },
  60410: {
    code: "TWILIO_DELIVERY_BLOCKED",
    httpStatus: 429,
    message: "Verification delivery is temporarily blocked. Try again later.",
  },
  60605: {
    code: "TWILIO_GEO_BLOCKED",
    httpStatus: 403,
    message: "SMS verification is not enabled for this country in Twilio Verify geo permissions.",
  },
}

export class TwilioVerifyError extends Error {
  readonly code: string
  readonly httpStatus: number
  readonly twilioCode?: number

  constructor(
    message: string,
    code: string,
    httpStatus: number,
    twilioCode?: number,
  ) {
    super(message)
    this.name = "TwilioVerifyError"
    this.code = code
    this.httpStatus = httpStatus
    this.twilioCode = twilioCode
  }
}

export function isTwilioVerifyError(err: unknown): err is TwilioVerifyError {
  return err instanceof TwilioVerifyError
}

function mapTwilioVerifyError(
  data: Record<string, unknown>,
  fallbackStatus: number,
): TwilioVerifyError {
  const twilioCode = typeof data.code === "number" ? data.code : undefined
  const mapped = twilioCode ? TWILIO_VERIFY_ERRORS[twilioCode] : undefined
  const message = typeof data.message === "string"
    ? data.message
    : "Twilio Verify request failed"

  if (mapped) {
    return new TwilioVerifyError(
      mapped.message,
      mapped.code,
      mapped.httpStatus,
      twilioCode,
    )
  }

  return new TwilioVerifyError(
    message,
    "TWILIO_ERROR",
    fallbackStatus >= 400 && fallbackStatus < 600 ? fallbackStatus : 502,
    twilioCode,
  )
}

function twilioConfig() {
  const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID")
  const authToken = Deno.env.get("TWILIO_AUTH_TOKEN")
  const serviceSid = Deno.env.get("TWILIO_VERIFY_SERVICE_SID")
  if (!accountSid || !authToken || !serviceSid) {
    throw new Error("Twilio Verify is not configured")
  }
  return { accountSid, authToken, serviceSid }
}

function twilioAuthHeader(accountSid: string, authToken: string): string {
  return "Basic " + btoa(`${accountSid}:${authToken}`)
}

export async function twilioStartVerification(
  to: string,
  channel: TwilioChannel,
  purpose: string,
): Promise<{ sid: string; status: string }> {
  const { accountSid, authToken, serviceSid } = twilioConfig()
  const flow = purpose.toUpperCase()

  logOtp("info", flow, { source: "Twilio", action: "start_verification", channel, to: to.slice(0, 4) + "***" })

  const body = new URLSearchParams({ To: to, Channel: channel })
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${serviceSid}/Verifications`,
    {
      method: "POST",
      headers: {
        Authorization: twilioAuthHeader(accountSid, authToken),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    },
  )

  const data = await response.json()
  if (!response.ok) {
    const err = mapTwilioVerifyError(data, response.status)
    logOtp("error", flow, {
      source: "Twilio",
      action: "start_verification",
      status: response.status,
      twilio_code: err.twilioCode,
      code: err.code,
      message: err.message,
    })
    throw err
  }

  return { sid: data.sid, status: data.status }
}

export async function twilioCheckVerification(
  to: string,
  code: string,
  purpose: string,
): Promise<{ valid: boolean; status: string; error?: TwilioVerifyError }> {
  const { accountSid, authToken, serviceSid } = twilioConfig()
  const flow = purpose.toUpperCase()

  const body = new URLSearchParams({ To: to, Code: code })
  const response = await fetch(
    `https://verify.twilio.com/v2/Services/${serviceSid}/VerificationCheck`,
    {
      method: "POST",
      headers: {
        Authorization: twilioAuthHeader(accountSid, authToken),
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    },
  )

  const data = await response.json()
  if (!response.ok) {
    const err = mapTwilioVerifyError(data, response.status)
    logOtp("error", flow, {
      source: "Twilio",
      action: "check_verification",
      status: response.status,
      twilio_code: err.twilioCode,
      code: err.code,
      message: err.message,
    })
    return { valid: false, status: data.status ?? "failed", error: err }
  }

  // Wrong code returns 200 with status "pending" — not an HTTP error (Twilio Verify v2).
  return { valid: data.status === "approved", status: data.status }
}

export function isTwilioConfigured(): boolean {
  return Boolean(
    Deno.env.get("TWILIO_ACCOUNT_SID") &&
      Deno.env.get("TWILIO_AUTH_TOKEN") &&
      Deno.env.get("TWILIO_VERIFY_SERVICE_SID"),
  )
}
