import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    // Require at minimum the apikey header (anon key) to prevent fully anonymous access
    const apikey = req.headers.get('apikey')
    if (!apikey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: corsHeaders })
    }

    const { target, target_type, otp_code } = await req.json()
    
    if (!target || !target_type || !otp_code) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400, headers: corsHeaders })
    }

    if (typeof otp_code !== 'string' || otp_code.length !== 6 || !/^\d{6}$/.test(otp_code)) {
      return new Response(JSON.stringify({ error: "Invalid OTP format" }), { status: 400, headers: corsHeaders })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Target-level rate limiting: max 10 verification attempts per target per 15 min
    const { data: recentAttempts } = await supabaseAdmin
      .from('otp_verifications')
      .select('attempts')
      .eq('target', target)
      .is('used_at', null)
      .gt('created_at', new Date(Date.now() - 15 * 60000).toISOString())

    const totalAttempts = (recentAttempts || []).reduce((sum: number, r: any) => sum + (r.attempts || 0), 0)
    if (totalAttempts >= 15) {
      return new Response(JSON.stringify({ 
        error: 'Too many verification attempts. Please wait before retrying.', 
        code: 'RATE_LIMIT_EXCEEDED' 
      }), { status: 429, headers: corsHeaders })
    }

    const hashOtp = async (value: string): Promise<string> => {
      const msgUint8 = new TextEncoder().encode(value)
      const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8)
      const hashArray = Array.from(new Uint8Array(hashBuffer))
      return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
    }

    const providedHashHex = await hashOtp(otp_code)

    const targetVariants = target_type === 'phone'
      ? [...new Set([
          String(target).trim(),
          String(target).trim().startsWith('+')
            ? String(target).trim().slice(1)
            : `+${String(target).trim()}`,
        ])]
      : [String(target).trim()]

    let otp: Record<string, unknown> | null = null
    for (const targetVariant of targetVariants) {
      const { data: candidates, error: lookupError } = await supabaseAdmin
        .from('otp_verifications')
        .select('*')
        .eq('target', targetVariant)
        .eq('target_type', target_type)
        .is('used_at', null)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(5)

      if (!lookupError && candidates) {
        for (const record of candidates) {
          if (record.code_hash === providedHashHex) {
            otp = record
            break
          }
          if (record.hash_salt) {
            const saltedHash = await hashOtp(`${record.hash_salt}${otp_code}`)
            if (record.code_hash === saltedHash) {
              otp = record
              break
            }
          }
        }
      }
      if (otp) break
    }

    if (!otp) {
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
    const attempts = Number(otp.attempts ?? 0)
    const maxAttempts = Number(otp.max_attempts ?? 5)
    if (attempts >= maxAttempts) {
      return new Response(JSON.stringify({ 
        error: 'Too many attempts', 
        code: 'MAX_ATTEMPTS' 
      }), { status: 403, headers: corsHeaders })
    }

    const { error: updateError } = await supabaseAdmin
      .from('otp_verifications')
      .update({
        verified_at: new Date().toISOString(),
        used_at: new Date().toISOString(),
      })
      .eq('id', otp.id)

    if (updateError) throw updateError

    if (
      target_type === 'phone' &&
      (otp.type === 'verification' || otp.type === 'phone_change') &&
      otp.user_id
    ) {
      const { error: confirmError } = await supabaseAdmin.auth.admin.updateUserById(
        String(otp.user_id),
        { phone_confirm: true },
      )
      if (confirmError) {
        console.error('[OTP] Failed to confirm phone:', confirmError.message)
      }
    }

    return new Response(JSON.stringify({ 
      success: true, 
      purpose: otp.type
    }), { status: 200, headers: corsHeaders })

  } catch (err: any) {
    console.error('[OTP] Verify Error:', err)
    return new Response(JSON.stringify({ error: err.message || 'Internal Error' }), { status: 500, headers: corsHeaders })
  }
})
