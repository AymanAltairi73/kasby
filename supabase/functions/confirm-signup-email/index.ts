import { serve } from "std/http/server.ts"
import { createClient } from "supabase"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

async function sha256Hex(value: string): Promise<string> {
  const hashBuffer = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  )
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const apikey = req.headers.get("apikey")
    if (!apikey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      })
    }

    const { email, otp_code } = await req.json()
    if (!email || !otp_code) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const normalizedEmail = String(email).trim().toLowerCase()
    const normalizedOtp = String(otp_code).replace(/\D/g, "")

    if (normalizedOtp.length !== 6) {
      return new Response(JSON.stringify({ error: "Invalid OTP format" }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const otpHash = await sha256Hex(normalizedOtp)

    const { data: otp, error: otpError } = await supabaseAdmin
      .from("otp_verifications")
      .select("*")
      .eq("target", normalizedEmail)
      .eq("target_type", "email")
      .eq("purpose", "signup")
      .eq("otp_hash", otpHash)
      .eq("is_used", false)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle()

    if (otpError || !otp) {
      return new Response(JSON.stringify({
        error: "Invalid or expired OTP",
        code: "INVALID_OTP",
      }), { status: 400, headers: corsHeaders })
    }

    const { data: profile, error: profileError } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("email", normalizedEmail)
      .maybeSingle()

    if (profileError || !profile?.id) {
      return new Response(JSON.stringify({
        error: "User profile not found",
        code: "USER_NOT_FOUND",
      }), { status: 404, headers: corsHeaders })
    }

    const { error: confirmError } = await supabaseAdmin.auth.admin.updateUserById(
      profile.id,
      { email_confirm: true },
    )

    if (confirmError) {
      throw confirmError
    }

    await supabaseAdmin
      .from("otp_verifications")
      .update({ is_used: true })
      .eq("id", otp.id)

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    })
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : "Internal Error"
    console.error("[confirm-signup-email] Error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
