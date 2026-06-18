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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { email, otp_code } = await req.json()

    if (!email || !otp_code) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: corsHeaders },
      )
    }

    const sanitizedEmail = String(email).trim().toLowerCase()
    const normalizedCode = String(otp_code).replace(/\D/g, "")
    const providedHash = await hashOtp(normalizedCode)

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const { data: otp, error } = await supabaseAdmin
      .from("otp_verifications")
      .select("*")
      .eq("target", sanitizedEmail)
      .eq("target_type", "email")
      .eq("type", "signup")
      .eq("code_hash", providedHash)
      .is("used_at", null)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle()

    if (error || !otp) {
      return new Response(
        JSON.stringify({ error: "Invalid or expired OTP", code: "INVALID_OTP" }),
        { status: 400, headers: corsHeaders },
      )
    }

    if (otp.attempts >= otp.max_attempts) {
      return new Response(
        JSON.stringify({ error: "Too many attempts", code: "MAX_ATTEMPTS" }),
        { status: 403, headers: corsHeaders },
      )
    }

    const { error: markUsedError } = await supabaseAdmin
      .from("otp_verifications")
      .update({
        used_at: new Date().toISOString(),
        verified_at: new Date().toISOString(),
      })
      .eq("id", otp.id)

    if (markUsedError) throw markUsedError

    const { error: confirmError } = await supabaseAdmin.auth.admin
      .updateUserById(otp.user_id, { email_confirm: true })

    if (confirmError) throw confirmError

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: corsHeaders,
    })
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Internal Error"
    console.error("[confirm-signup-email] Error:", message)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
