import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

/**
 * HARDENED SEND OTP
 * 
 * Flow:
 * 1. Validate Input
 * 2. Find User (if password_reset)
 * 3. Rate Limit (1 per min, 5 per 15 min)
 * 4. Generate 6-digit OTP
 * 5. Hash OTP (SHA-256)
 * 6. Store in otp_verifications
 * 7. Send via FCM Push Notification (SECURE — OTP never in HTTP response)
 */

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })

  try {
    const { target, target_type, purpose, device_fcm_token } = await req.json()
    
    if (!target || !target_type || !purpose) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400, headers: corsHeaders })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Identify User
    let userId: string | null = null
    const authHeader = req.headers.get('Authorization')
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const token = authHeader.replace('Bearer ', '').trim()
        
        // Only verify if it doesn't look like the anon key (too short or missing dots)
        if (token.includes('.') && token.length > 40) {
          const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)
          
          if (authError) {
            console.error('[OTP] Auth getUser error:', authError.message)
          }
          
          userId = user?.id || null
          if (userId) console.log(`[OTP] Identified user: ${userId}`)
        } else {
          console.log('[OTP] Token provided but looks like anon key or invalid format')
        }
      } catch (e) {
        console.error('[OTP] Auth token verification critical failure:', e.message)
      }
    } else {
      console.log('[OTP] No Authorization Bearer header found')
    }

    // For password reset, ALWAYS look up user by target (email/phone)
    // even if a JWT userId was found — the JWT user might be different
    // from the password reset target.
    if (purpose === 'password_reset') {
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('id')
        .eq(target_type === 'email' ? 'email' : 'phone', target)
        .maybeSingle()
      
      if (profile?.id) {
        userId = profile.id
        console.log(`[OTP] Password reset: resolved target ${target} to user ${userId}`)
      } else {
        console.log(`[OTP] Password reset: no profile found for ${target_type}=${target}`)
        userId = null
      }
    }

    if (!userId) {
      return new Response(JSON.stringify({ success: true, message: "If this account exists, an OTP has been sent." }), { status: 200, headers: corsHeaders })
    }

    // 2. Rate Limiting Check
    const { data: recentOtps } = await supabaseAdmin
      .from('otp_verifications')
      .select('created_at')
      .eq('user_id', userId)
      .gt('created_at', new Date(Date.now() - 15 * 60000).toISOString())
    
    if (recentOtps && recentOtps.length >= 5) {
      return new Response(JSON.stringify({ error: 'Too many requests. Please wait 15 minutes.', code: 'RATE_LIMIT_EXCEEDED' }), { status: 429, headers: corsHeaders })
    }

    const lastOtp = recentOtps?.[recentOtps.length - 1]
    if (lastOtp && new Date(lastOtp.created_at).getTime() > Date.now() - 60000) {
      return new Response(JSON.stringify({ error: 'Please wait 60 seconds.', code: 'RATE_LIMIT_EXCEEDED' }), { status: 429, headers: corsHeaders })
    }

    // 3. Generate 6-digit OTP (cryptographically secure)
    const randomBytes = new Uint32Array(1)
    crypto.getRandomValues(randomBytes)
    const otpCode = (100000 + (randomBytes[0] % 900000)).toString()
    
    // 4. Hash OTP (SHA-256 with salt)
    const salt = `${userId}:${Date.now()}`
    const msgUint8 = new TextEncoder().encode(salt + otpCode)
    const hashBuffer = await crypto.subtle.digest('SHA-256', msgUint8)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    // 5. Secure Storage
    const { error: insertError } = await supabaseAdmin
      .from('otp_verifications')
      .insert({
        user_id: userId,
        target: target,
        target_type: target_type,
        type: purpose,
        code_hash: hashHex,
        hash_salt: salt,
        expires_at: new Date(Date.now() + 5 * 60000).toISOString()
      })

    if (insertError) throw insertError

    // 6. DELIVERY via FCM Push Notification
    // OTP is delivered ONLY through the secure FCM channel — NEVER in HTTP responses.
    let deliveryStatus = 'no_fcm_token'

    if (device_fcm_token) {
      console.log(`[OTP] Delivering OTP via FCM to user ${userId} for ${purpose}`)
      
      try {
        const fcmResponse = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/send-fcm`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`
          },
          body: JSON.stringify({
            token: device_fcm_token,
            title: "Kasby — رمز التحقق",
            body: `رمز التحقق الخاص بك هو: ${otpCode}`,
            data: {
              type: "otp_verification",
              purpose: purpose,
              otp_code: otpCode
            }
          })
        })

        if (fcmResponse.ok) {
          deliveryStatus = 'delivered'
          console.log(`[OTP] FCM delivery successful for user ${userId}`)
        } else {
          const errText = await fcmResponse.text()
          deliveryStatus = 'fcm_failed'
          console.error(`[OTP] FCM delivery failed: ${errText}`)
        }
      } catch (fcmErr: any) {
        deliveryStatus = 'fcm_error'
        console.error(`[OTP] FCM delivery error: ${fcmErr.message}`)
      }
    } else {
      console.log(`[OTP] No FCM token provided for user ${userId}. OTP stored but not delivered.`)
    }

    // SECURITY: OTP is NEVER included in the HTTP response.
    // It is delivered exclusively via the FCM push notification channel.
    return new Response(JSON.stringify({ 
      success: true,
      delivery: deliveryStatus,
      expires_in_seconds: 300 
    }), { status: 200, headers: corsHeaders })

  } catch (err: any) {
    console.error('[OTP] Error:', err)
    return new Response(JSON.stringify({ error: err.message || 'Internal Error' }), { status: 500, headers: corsHeaders })
  }
})
