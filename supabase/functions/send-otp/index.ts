import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
}

async function hashOtp(code: string): Promise<string> {
  const msgUint8 = new TextEncoder().encode(code)
  const hashBuffer = await crypto.subtle.digest("SHA-256", msgUint8)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("")
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

  if (purpose === "password_reset" || purpose === "signup") {
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq(targetType === "email" ? "email" : "phone", target)
      .maybeSingle()

    if (profile?.id) return profile.id
  }

  if (purpose === "signup" && targetType === "email") {
    const { data: authData } = await supabaseAdmin.auth.admin.listUsers()
    const match = authData.users.find(
      (u) => u.email?.toLowerCase() === target.toLowerCase(),
    )
    if (match?.id) return match.id
  }

  return null
}

async function sendEmailViaResend(
  to: string,
  otpCode: string,
  purpose: string,
): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY")
  const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ??
    "Kasby <noreply@kasby.app>"

  if (!apiKey) {
    throw new Error("RESEND_API_KEY is not configured")
  }

  const subject = purpose === "signup"
    ? "رمز تأكيد حسابك في كاسبي"
    : "رمز التحقق - كاسبي"

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
    throw new Error(`Resend delivery failed: ${body}`)
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { target, target_type, purpose } = await req.json()

    if (!target || !target_type || !purpose) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: corsHeaders },
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const userId = await resolveUserId(
      supabaseAdmin,
      target,
      target_type,
      purpose,
      req.headers.get("Authorization"),
    )

    if (!userId) {
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

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString()
    const hashHex = await hashOtp(otpCode)

    const { error: insertError } = await supabaseAdmin
      .from("otp_verifications")
      .insert({
        user_id: userId,
        target,
        target_type,
        type: purpose,
        code_hash: hashHex,
        expires_at: new Date(Date.now() + 5 * 60000).toISOString(),
      })

    if (insertError) throw insertError

    if (target_type === "email") {
      await sendEmailViaResend(target, otpCode, purpose)
    }

    return new Response(
      JSON.stringify({ success: true, expires_in_seconds: 300 }),
      { status: 200, headers: corsHeaders },
    )
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Internal Error"
    console.error("[send-otp] Error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
