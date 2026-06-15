import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/**
 * SECURE PASSWORD RESET
 * 
 * Flow:
 * 1. Verify OTP (Hash check, Not used, Not expired)
 * 2. Update auth.users password (via service_role)
 * 3. Mark OTP as used
 * 4. Log activity
 */

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { target, otp_code, new_password } = await req.json()
    
    if (!target || !otp_code || !new_password) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400, headers: corsHeaders })
    }

    if (typeof new_password !== 'string' || new_password.length < 8) {
      return new Response(JSON.stringify({ error: "Password must be at least 8 characters", code: 'WEAK_PASSWORD' }), { status: 400, headers: corsHeaders })
    }

    if (!/[A-Za-z]/.test(new_password) || !/[0-9]/.test(new_password)) {
      return new Response(JSON.stringify({ error: "Password must contain both letters and numbers", code: 'WEAK_PASSWORD' }), { status: 400, headers: corsHeaders })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const authHeader = req.headers.get('Authorization')
    let userId: string | null = null
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.replace('Bearer ', '')
        if (token.includes('.') && token.length > 40) {
          const { data: { user } } = await supabaseAdmin.auth.getUser(token)
          userId = user?.id || null
        }
      } catch (e) {
        console.log('[OTP] Auth token verification skipped or failed')
      }
    }

    // 1. Hash the provided code for comparison
    const msgUint8 = new TextEncoder().encode(otp_code)
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const providedHashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    // 2. Find and validate the OTP record
    const { data: otp, error } = await supabaseAdmin
      .from('otp_verifications')
      .select('*')
      .eq('target', target)
      .eq('code_hash', providedHashHex)
      .eq('type', 'password_reset') // Strict type check
      .is('used_at', null)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (error || !otp) {
      // Track failed attempts on the most recent unused OTP for this target
      const { data: latestOtp } = await supabaseAdmin
        .from('otp_verifications')
        .select('id, attempts')
        .eq('target', target)
        .eq('type', 'password_reset')
        .is('used_at', null)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      if (latestOtp) {
        const newAttempts = (latestOtp.attempts || 0) + 1
        await supabaseAdmin
          .from('otp_verifications')
          .update({ attempts: newAttempts })
          .eq('id', latestOtp.id)

        if (newAttempts >= 5) {
          await supabaseAdmin
            .from('otp_verifications')
            .update({ used_at: new Date().toISOString() })
            .eq('id', latestOtp.id)
          return new Response(JSON.stringify({ error: 'Maximum attempts exceeded. Please request a new code.', code: 'MAX_ATTEMPTS' }), { status: 403, headers: corsHeaders })
        }
      }

      return new Response(JSON.stringify({ error: 'Invalid or expired OTP code', code: 'INVALID_OTP' }), { status: 400, headers: corsHeaders })
    }

    // 3. Perform Password Reset
    const { error: resetError } = await supabaseAdmin.auth.admin.updateUserById(
      otp.user_id,
      { password: new_password }
    )

    if (resetError) throw resetError

    // 4. Mark OTP as used
    await supabaseAdmin
      .from('otp_verifications')
      .update({ used_at: new Date().toISOString() })
      .eq('id', otp.id)

    // 5. Log activity
    await supabaseAdmin.from('system_logs').insert({
      actor_id: otp.user_id,
      action: 'password_reset_secure',
      details: { message: 'Password reset via custom OTP system' },
      severity: 'info',
      actor_role: 'user',
      entity_type: 'user'
    })

    return new Response(JSON.stringify({ success: true, message: 'Password reset successful' }), { status: 200, headers: corsHeaders })

  } catch (err: any) {
    console.error('[RESET_PWD] Error:', err)
    return new Response(JSON.stringify({ error: err.message || 'Internal Error' }), { status: 500, headers: corsHeaders })
  }
})
