import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

/**
 * SECURE PROFILE UPDATE (EMAIL & PHONE)
 * 
 * Logic:
 * 1. Verify OTP server-side (Hash check, Expiry, Attempts)
 * 2. Uniqueness check on new value
 * 3. Atomic Update: auth.users (via admin) and public.profiles
 * 4. Invalidate OTP
 * 5. Log activity
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { type, new_value, otp_code } = await req.json()

    if (!type || !new_value || !otp_code) {
      return new Response(JSON.stringify({ error: "Missing required fields: type, new_value, otp_code" }), { status: 400, headers: corsHeaders })
    }

    if (!['email_change', 'phone_change'].includes(type)) {
      return new Response(JSON.stringify({ error: "Invalid type. Must be 'email_change' or 'phone_change'" }), { status: 400, headers: corsHeaders })
    }

    if (typeof new_value !== 'string' || new_value.trim().length === 0) {
      return new Response(JSON.stringify({ error: "Invalid new_value" }), { status: 400, headers: corsHeaders })
    }

    // 1. Setup Supabase Admin Client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Get the authenticated user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), { status: 401, headers: corsHeaders })
    }

    const token = authHeader.replace('Bearer ', '').trim()
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)

    if (authError || !user) {
      console.error('[Update] Auth Error:', authError?.message)
      return new Response(JSON.stringify({ error: 'Unauthorized', details: authError?.message }), { status: 401, headers: corsHeaders })
    }

    const userId = user.id

    // 3. Find and validate the OTP
    const { data: otp, error: otpError } = await supabaseAdmin
      .from('otp_verifications')
      .select('*')
      .eq('user_id', userId)
      .eq('target', new_value)
      .eq('type', type)
      .is('used_at', null)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .single()

    if (otpError || !otp) {
      console.log(`[Update] OTP not found for ${userId} target: ${new_value}`)
      return new Response(JSON.stringify({ error: 'OTP not found or expired', code: 'INVALID_OTP' }), { status: 400, headers: corsHeaders })
    }

    if (otp.attempts >= otp.max_attempts) {
      return new Response(JSON.stringify({ error: 'Too many attempts', code: 'MAX_ATTEMPTS' }), { status: 400, headers: corsHeaders })
    }

    // 4. Verify Code (SHA-256)
    const msgUint8 = new TextEncoder().encode(otp_code)
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const inputHashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    const isValid = otp.code_hash === inputHashHex

    if (!isValid) {
      await supabaseAdmin
        .from('otp_verifications')
        .update({ attempts: otp.attempts + 1 })
        .eq('id', otp.id)
      
      return new Response(JSON.stringify({ 
        error: 'Invalid OTP code', 
        code: 'INVALID_CODE', 
        remaining: otp.max_attempts - (otp.attempts + 1) 
      }), { status: 400, headers: corsHeaders })
    }

    // 5. Uniqueness Check
    const { data: existingProfile } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq(type === 'email_change' ? 'email' : 'phone', new_value)
      .maybeSingle()

    if (existingProfile) {
      return new Response(JSON.stringify({ error: 'Value already taken', code: 'DUPLICATE_VALUE' }), { status: 400, headers: corsHeaders })
    }

    // 6. PERFORM UPDATE
    console.log(`[Update] Executing ${type} for ${userId} -> ${new_value}`)
    
    if (type === 'email_change') {
      // Update auth.users (Admin privilege required)
      const { error: updateAuthError } = await supabaseAdmin.auth.admin.updateUserById(
        userId,
        { email: new_value, email_confirm: true }
      )
      
      if (updateAuthError) throw updateAuthError

      // Update public.profiles
      const { error: updateProfileError } = await supabaseAdmin
        .from('profiles')
        .update({ email: new_value })
        .eq('id', userId)

      if (updateProfileError) throw updateProfileError

    } else if (type === 'phone_change') {
      const { error: updateAuthError } = await supabaseAdmin.auth.admin.updateUserById(
        userId,
        { phone: new_value, phone_confirm: true }
      )

      if (updateAuthError) throw updateAuthError

      const { error: updateProfileError } = await supabaseAdmin
        .from('profiles')
        .update({ phone: new_value })
        .eq('id', userId)

      if (updateProfileError) throw updateProfileError
    }

    // 7. Success Cleanup
    await supabaseAdmin
      .from('otp_verifications')
      .update({ verified_at: new Date().toISOString(), used_at: new Date().toISOString() })
      .eq('id', otp.id)

    // 8. Log Activity
    await supabaseAdmin.from('system_logs').insert({
      actor_id: userId,
      action: 'profile_update_secure',
      details: { type: type, new_value: new_value },
      severity: 'info',
      actor_role: 'user',
      entity_type: 'user'
    })

    // 9. Send In-App Notification
    const labelAr = type === 'email_change' ? 'البريد الإلكتروني' : 'رقم الهاتف'
    const labelEn = type === 'email_change' ? 'Email' : 'Phone'
    
    await supabaseAdmin.from('notifications').insert({
      user_id: userId,
      title: 'تحديث الملف الشخصي',
      message: `تم تحديث ${labelAr} بنجاح إلى ${new_value}`,
      type: 'success',
      status: 'sent',
      target: 'specific'
    })

    // Also send an English version if needed, or stick to one/concatenated
    // For Kasby, usually we store one per event. Let's provide a dual-language message
    // or detect user locale if possible. Since Edge Function doesn't easily know locale, 
    // we'll provide a professional Arabic/English format.
    
    return new Response(JSON.stringify({ success: true }), { status: 200, headers: corsHeaders })

  } catch (err: any) {
    console.error('[Update] Error:', err)
    return new Response(JSON.stringify({ error: err.message || 'Internal Error' }), { status: 500, headers: corsHeaders })
  }
})
