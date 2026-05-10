import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { target, target_type, otp_code } = await req.json()
    
    if (!target || !target_type || !otp_code) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400, headers: corsHeaders })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Identify User (optional for verification but helpful)
    let userId: string | null = null
    const authHeader = req.headers.get('Authorization')
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

    // 2. Hash the provided code for comparison
    const msgUint8 = new TextEncoder().encode(otp_code)
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const providedHashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    // 3. Find and validate the OTP record
    const { data: otp, error } = await supabaseAdmin
      .from('otp_verifications')
      .select('*')
      .eq('target', target)
      .eq('target_type', target_type)
      .eq('code_hash', providedHashHex)
      .is('used_at', null)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (error || !otp) {
      // Logic for failed attempt: increment attempts on the most recent valid-looking record
      const { data: recentRecord } = await supabaseAdmin
        .from('otp_verifications')
        .select('*')
        .eq('target', target)
        .is('used_at', null)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      if (recentRecord) {
        await supabaseAdmin
          .from('otp_verifications')
          .update({ attempts: recentRecord.attempts + 1 })
          .eq('id', recentRecord.id)
        
        const remaining = recentRecord.max_attempts - (recentRecord.attempts + 1)
        if (remaining <= 0) {
           return new Response(JSON.stringify({ 
             error: 'Too many failed attempts. Code invalidated.', 
             code: 'MAX_ATTEMPTS' 
           }), { status: 403, headers: corsHeaders })
        }
      }

      return new Response(JSON.stringify({ 
        error: 'Invalid or expired OTP', 
        code: 'INVALID_OTP' 
      }), { status: 400, headers: corsHeaders })
    }

    // Check attempts on the found record too (just in case)
    if (otp.attempts >= otp.max_attempts) {
      return new Response(JSON.stringify({ 
        error: 'Too many attempts', 
        code: 'MAX_ATTEMPTS' 
      }), { status: 403, headers: corsHeaders })
    }

    // 4. Mark as Verified (but NOT used yet, if the operation happens separately)
    // For profile updates, they use 'secure-profile-update' which does its own check.
    // For password reset, the next step needs to know it was verified.
    const { error: updateError } = await supabaseAdmin
      .from('otp_verifications')
      .update({ verified_at: new Date().toISOString() })
      .eq('id', otp.id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ 
      success: true, 
      purpose: otp.type,
      user_id: otp.user_id 
    }), { status: 200, headers: corsHeaders })

  } catch (err: any) {
    console.error('[OTP] Verify Error:', err)
    return new Response(JSON.stringify({ error: err.message || 'Internal Error' }), { status: 500, headers: corsHeaders })
  }
})
