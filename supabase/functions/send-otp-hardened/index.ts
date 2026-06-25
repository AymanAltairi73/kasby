import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

const DEFAULT_FROM = "Kasby <onboarding@kasby.resend.com>"

function logEmail(
  level: "info" | "error",
  flow: string,
  details: Record<string, unknown>,
) {
  const prefix = `[EMAIL][${flow}]`
  if (level === "error") {
    console.error(prefix, JSON.stringify(details))
  } else {
    console.log(prefix, JSON.stringify(details))
  }
}

async function hashOtp(code: string): Promise<string> {
  const msgUint8 = new TextEncoder().encode(code)
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("")
}

async function findAuthUserByEmail(
  supabaseAdmin: ReturnType<typeof createClient>,
  email: string,
): Promise<string | null> {
  let page = 1
  while (page <= 5) {
    const { data: authData, error: listError } = await supabaseAdmin.auth.admin
      .listUsers({ page, perPage: 200 })
    if (listError) break
    const match = authData.users.find(
      (u) => u.email?.toLowerCase() === email.toLowerCase(),
    )
    if (match?.id) return match.id
    if (authData.users.length < 200) break
    page++
  }
  return null
}

async function resolveUserId(
  supabaseAdmin: ReturnType<typeof createClient>,
  target: string,
  targetType: string,
  purpose: string,
  authHeader: string | null,
): Promise<string | null> {
  if (authHeader?.startsWith("Bearer ")) {
    const token = authHeader.replace("Bearer ", "").trim()
    if (token.includes(".") && token.length > 40) {
      const { data: { user } } = await supabaseAdmin.auth.getUser(token)
      if (user?.id) return user.id
    }
  }

  const lookupPurposes = new Set([
    "password_reset",
    "signup",
    "verification",
    "phone_change",
    "email_change",
  ])

  if (lookupPurposes.has(purpose)) {
    if (targetType === "phone") {
      const profile = await resolveProfileByPhone(supabaseAdmin, target)
      if (profile?.id) return profile.id
    } else {
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("id")
        .eq("email", target)
        .maybeSingle()

      if (profile?.id) return profile.id

      const { data: profileIlike } = await supabaseAdmin
        .from("profiles")
        .select("id")
        .ilike("email", target)
        .maybeSingle()
      if (profileIlike?.id) return profileIlike.id

      const authUserId = await findAuthUserByEmail(supabaseAdmin, target)
      if (authUserId) return authUserId
    }
  }

  return null
}

function phoneLookupVariants(phone: string): string[] {
  const trimmed = String(phone).trim()
  const withoutPlus = trimmed.startsWith("+") ? trimmed.slice(1) : trimmed
  const withPlus = trimmed.startsWith("+") ? trimmed : `+${trimmed}`
  return [...new Set([trimmed, withPlus, withoutPlus].filter(Boolean))]
}

async function resolveProfileByPhone(
  supabaseAdmin: ReturnType<typeof createClient>,
  target: string,
): Promise<{ id: string; phone: string } | null> {
  for (const variant of phoneLookupVariants(target)) {
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("id, phone")
      .eq("phone", variant)
      .maybeSingle()

    if (profile?.id && profile.phone) {
      return { id: profile.id, phone: profile.phone }
    }
  }
  return null
}

async function sendEmailViaResend(
  to: string,
  otpCode: string,
  purpose: string,
  flow: string,
): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY")
  const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ?? DEFAULT_FROM

  if (!apiKey) {
    logEmail("error", flow, {
      source: "Resend",
      status: 500,
      message: "RESEND_API_KEY is not configured",
    })
    throw new Error("RESEND_API_KEY is not configured")
  }

  const subject = purpose === "signup"
    ? "رمز تأكيد حسابك في كاسبي"
    : purpose === "password_reset"
    ? "رمز إعادة تعيين كلمة المرور - كاسبي"
    : "رمز التحقق - كاسبي"

  logEmail("info", flow, {
    source: "Resend",
    action: "send",
    to: to.replace(/(.{2}).+(@.+)/, "$1***$2"),
    from: fromEmail,
    purpose,
  })

  const resendResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [to],
      subject,
      html: `
        <div dir="rtl" style="font-family: Arial, sans-serif; padding: 24px;">
          <h2>كاسبي</h2>
          <p>رمز التحقق الخاص بك هو:</p>
          <p style="font-size: 32px; font-weight: bold; letter-spacing: 6px;">${otpCode}</p>
          <p>ينتهي خلال 5 دقائق.</p>
        </div>
      `,
    }),
  })

  if (!resendResponse.ok) {
    const body = await resendResponse.text()
    logEmail("error", flow, {
      source: "Resend",
      status: resendResponse.status,
      message: body,
    })
    throw new Error(`Resend delivery failed: ${body}`)
  }

  logEmail("info", flow, {
    source: "Resend",
    status: resendResponse.status,
    message: "Email accepted by Resend",
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const startedAt = Date.now()

  try {
    const body = await req.json()
    const {
      target,
      target_type,
      purpose,
      device_fcm_token,
      provision_password,
      provision_metadata,
    } = body

    if (!target || !target_type || !purpose) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: corsHeaders },
      )
    }

    const flow = String(purpose).toUpperCase()
    logEmail("info", flow, {
      source: "send-otp-hardened",
      action: "request",
      target_type,
      purpose,
    })

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const normalizedTarget = target_type === "email"
      ? String(target).trim().toLowerCase()
      : String(target).trim()

    let deliveryTarget = normalizedTarget
    if (target_type === "phone" && purpose !== "phone_change") {
      const profile = await resolveProfileByPhone(supabaseAdmin, normalizedTarget)
      if (profile?.phone) {
        deliveryTarget = profile.phone
      }
    }

    let userId = await resolveUserId(
      supabaseAdmin,
      deliveryTarget,
      target_type,
      purpose,
      req.headers.get("Authorization"),
    )

    if (
      !userId &&
      purpose === "signup" &&
      target_type === "email" &&
      provision_password
    ) {
      logEmail("info", flow, {
        source: "Supabase Auth",
        action: "provision_user",
        email: normalizedTarget.replace(/(.{2}).+(@.+)/, "$1***$2"),
      })

      const { data: created, error: createError } = await supabaseAdmin.auth
        .admin.createUser({
          email: normalizedTarget,
          password: String(provision_password),
          email_confirm: false,
          user_metadata: provision_metadata ?? {},
        })

      if (createError) {
        const alreadyExists = createError.message.toLowerCase().includes(
          "already",
        )
        if (!alreadyExists) {
          logEmail("error", flow, {
            source: "Supabase Auth",
            status: 500,
            message: createError.message,
          })
          throw createError
        }
        userId = await findAuthUserByEmail(supabaseAdmin, normalizedTarget)
      } else {
        userId = created.user?.id ?? null
      }
    }

    if (!userId) {
      if (purpose === "password_reset") {
        logEmail("info", flow, {
          source: "send-otp-hardened",
          status: 200,
          message: "User not found — generic success (anti-enumeration)",
        })
        return new Response(
          JSON.stringify({
            success: true,
            message: "If this account exists, an OTP has been sent.",
          }),
          { status: 200, headers: corsHeaders },
        )
      }
      logEmail("error", flow, {
        source: "send-otp-hardened",
        status: 404,
        message: "User not found",
      })
      return new Response(JSON.stringify({ error: "User not found" }), {
        status: 404,
        headers: corsHeaders,
      })
    }

    const { data: recentOtps } = await supabaseAdmin
      .from("otp_verifications")
      .select("created_at")
      .eq("user_id", userId)
      .gt("created_at", new Date(Date.now() - 15 * 60000).toISOString())

    if (recentOtps && recentOtps.length >= 5) {
      return new Response(
        JSON.stringify({
          error: "Too many requests. Please wait 15 minutes.",
          code: "RATE_LIMIT_EXCEEDED",
        }),
        { status: 429, headers: corsHeaders },
      )
    }

    const lastOtp = recentOtps?.[recentOtps.length - 1]
    if (lastOtp && new Date(lastOtp.created_at).getTime() > Date.now() - 60000) {
      return new Response(
        JSON.stringify({
          error: "Please wait 60 seconds.",
          code: "RATE_LIMIT_EXCEEDED",
        }),
        { status: 429, headers: corsHeaders },
      )
    }

    const randomBytes = new Uint32Array(1)
    crypto.getRandomValues(randomBytes)
    const otpCode = (100000 + (randomBytes[0] % 900000)).toString()
    const hashHex = await hashOtp(otpCode)

    const { error: insertError } = await supabaseAdmin
      .from("otp_verifications")
      .insert({
        user_id: userId,
        target: deliveryTarget,
        target_type: target_type,
        type: purpose,
        code_hash: hashHex,
        expires_at: new Date(Date.now() + 5 * 60000).toISOString(),
      })

    if (insertError) {
      logEmail("error", flow, {
        source: "Postgres",
        status: 500,
        message: insertError.message,
      })
      throw insertError
    }

    let deliveryStatus = "pending"

    if (target_type === "email") {
      await sendEmailViaResend(normalizedTarget, otpCode, purpose, flow)
      deliveryStatus = "email_sent"
    } else if (device_fcm_token) {
      const fcmResponse = await fetch(
        `${Deno.env.get("SUPABASE_URL")}/functions/v1/send-fcm`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
          },
          body: JSON.stringify({
            token: device_fcm_token,
            title: "Kasby — رمز التحقق",
            body: `رمز التحقق الخاص بك هو: ${otpCode}`,
            data: {
              type: "otp_verification",
              purpose: purpose,
              otp_code: otpCode,
            },
          }),
        },
      )

      if (fcmResponse.ok) {
        deliveryStatus = "delivered"
      } else {
        const errText = await fcmResponse.text()
        logEmail("error", flow, {
          source: "FCM",
          status: fcmResponse.status,
          message: errText,
        })
        deliveryStatus = "fcm_failed"
      }
    } else {
      deliveryStatus = "no_fcm_token"
    }

    if (target_type === "phone" && deliveryStatus !== "delivered") {
      return new Response(
        JSON.stringify({
          error: "Unable to deliver OTP. Enable notifications and try again.",
          code: "DELIVERY_FAILED",
          delivery: deliveryStatus,
        }),
        { status: 503, headers: corsHeaders },
      )
    }

    logEmail("info", flow, {
      source: "send-otp-hardened",
      status: 200,
      delivery: deliveryStatus,
      duration_ms: Date.now() - startedAt,
    })

    return new Response(
      JSON.stringify({
        success: true,
        delivery: deliveryStatus,
        expires_in_seconds: 300,
      }),
      { status: 200, headers: corsHeaders },
    )
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Internal Error"
    logEmail("error", "OTP", {
      source: "send-otp-hardened",
      status: 500,
      message,
    })
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
