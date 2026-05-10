import { serve } from "std/http/server.ts"
import { createClient } from "supabase"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const { target, target_type, device_fcm_token, purpose } = body

    // ═══════════════════════════════════════════════════════
    // VALIDATION
    // ═══════════════════════════════════════════════════════

    if (!target || !target_type) {
      throw new Error('target and target_type are required')
    }

    if (!['phone', 'email'].includes(target_type)) {
      throw new Error('target_type must be "phone" or "email"')
    }

    if (target_type === 'phone' && !device_fcm_token) {
      throw new Error('device_fcm_token is required for phone verification')
    }

    // Basic format validation
    if (target_type === 'email' && !target.includes('@')) {
      throw new Error('Invalid email address')
    }

    if (target_type === 'phone' && target.length < 8) {
      throw new Error('Invalid phone number')
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // ═══════════════════════════════════════════════════════
    // 1. CHECK RATE LIMIT
    // ═══════════════════════════════════════════════════════

    const { data: isAllowed, error: rateLimitError } = await supabase.rpc('fn_check_otp_rate_limit', {
      p_target: target,
      p_target_type: target_type,
    })

    if (rateLimitError) throw rateLimitError
    if (!isAllowed) {
      return new Response(
        JSON.stringify({ error: 'Too many requests. Please try again in 15 minutes.', code: 'RATE_LIMITED' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ═══════════════════════════════════════════════════════
    // 2. GENERATE 6-DIGIT OTP (CSPRNG)
    // ═══════════════════════════════════════════════════════

    const otp_array = new Uint32Array(1)
    crypto.getRandomValues(otp_array)
    const otp_code = (otp_array[0] % 900000 + 100000).toString()

    // ═══════════════════════════════════════════════════════
    // 3. HASH OTP (SHA-256)
    // ═══════════════════════════════════════════════════════

    const encoder = new TextEncoder()
    const data = encoder.encode(otp_code)
    const hashBuffer = await crypto.subtle.digest("SHA-256", data)
    const otp_hash = Array.from(new Uint8Array(hashBuffer))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('')

    // 5-minute expiration
    const expires_at = new Date(Date.now() + 5 * 60_000).toISOString()

    // ═══════════════════════════════════════════════════════
    // 4. INVALIDATE PREVIOUS OTPs FOR THIS TARGET
    // ═══════════════════════════════════════════════════════

    await supabase
      .from('otp_verifications')
      .update({ is_used: true })
      .eq('target', target)
      .eq('target_type', target_type)
      .eq('is_used', false)

    // ═══════════════════════════════════════════════════════
    // 5. INSERT NEW OTP
    // ═══════════════════════════════════════════════════════

    const { error: insertError } = await supabase
      .from('otp_verifications')
      .insert({
        target,
        target_type,
        otp_hash,
        expires_at,
        attempts: 0,
        is_used: false,
        purpose: purpose || 'verification',
      })

    if (insertError) throw insertError

    // ═══════════════════════════════════════════════════════
    // 6. DELIVER OTP
    // ═══════════════════════════════════════════════════════

    if (target_type === 'phone') {
      // ─── PHONE: Send via FCM Data Message ───
      await sendFcmNotification(device_fcm_token, otp_code)
    } else {
      // ─── EMAIL: Send via Resend API ───
      await sendEmailOtp(target, otp_code)
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: target_type === 'phone'
          ? 'OTP sent via notification'
          : 'OTP sent to email',
        expires_in_seconds: 300,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('[send-otp] Error:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


// ═══════════════════════════════════════════════════════════
// FCM NOTIFICATION (Phone OTP)
// ═══════════════════════════════════════════════════════════

import { GoogleAuth } from "npm:google-auth-library@9";

async function sendFcmNotification(token: string, otp: string) {
  const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!serviceAccountStr) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT is not set in Supabase Secrets.');
  }

  const serviceAccount = JSON.parse(serviceAccountStr);
  const auth = new GoogleAuth({
    credentials: {
      client_email: serviceAccount.client_email,
      private_key: serviceAccount.private_key,
    },
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });

  const accessToken = await auth.getAccessToken();

  const payload = {
    message: {
      token: token,
      // Data-only message for auto-fill + local notification control
      data: {
        type: 'otp_verification',
        otp_code: otp,
        title: 'رمز التحقق من كاسبي',
        body: `رمز التحقق الخاص بك هو: ${otp}`,
      },
      // Also include notification for background/terminated state
      notification: {
        title: 'رمز التحقق من كاسبي',
        body: `رمز التحقق الخاص بك هو: ${otp}`,
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: 'high_importance_channel',
          sound: 'notification',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            'content-available': 1,
            sound: 'default',
            badge: 1,
          },
        },
      },
    },
  }

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
    }
  )

  const result = await response.json()
  if (!response.ok) {
    console.error('[send-otp] FCM Error:', result)
    throw new Error(`FCM delivery failed: ${JSON.stringify(result)}`)
  }
  return result
}


// ═══════════════════════════════════════════════════════════
// RESEND EMAIL (Email OTP)
// ═══════════════════════════════════════════════════════════

async function sendEmailOtp(email: string, otp: string) {
  const resendApiKey = Deno.env.get('RESEND_API_KEY')
  if (!resendApiKey) {
    throw new Error('RESEND_API_KEY is not set in Supabase Secrets.')
  }

  const fromEmail = Deno.env.get('RESEND_FROM_EMAIL') || 'kasby.resend.com'

  const htmlBody = `
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kasby Verification Code</title>
</head>
<body style="margin:0;padding:0;background-color:#0f172a;font-family:'Segoe UI',Tahoma,Geneva,Verdana,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background-color:#0f172a;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="460" cellpadding="0" cellspacing="0" role="presentation" style="background-color:#1e293b;border-radius:16px;overflow:hidden;border:1px solid rgba(201,163,77,0.2);">
          <!-- Header -->
          <tr>
            <td style="padding:32px 32px 16px;text-align:center;">
              <div style="font-size:28px;font-weight:900;color:#c9a34d;letter-spacing:2px;">KASBY</div>
              <div style="font-size:12px;color:#94a3b8;margin-top:4px;">Secure Verification</div>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding:0 32px;">
              <div style="height:1px;background:linear-gradient(90deg,transparent,#c9a34d,transparent);"></div>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px;">
              <p style="color:#e2e8f0;font-size:16px;margin:0 0 8px;text-align:center;">
                رمز التحقق الخاص بك
              </p>
              <p style="color:#94a3b8;font-size:13px;margin:0 0 24px;text-align:center;">
                Your Kasby verification code is:
              </p>

              <!-- OTP Code Box -->
              <div style="background-color:#0f172a;border:2px solid #c9a34d;border-radius:12px;padding:20px;text-align:center;margin:0 auto;max-width:280px;">
                <span style="font-size:36px;font-weight:900;color:#c9a34d;letter-spacing:12px;font-family:monospace;">
                  ${otp}
                </span>
              </div>

              <!-- Expiry Notice -->
              <p style="color:#f59e0b;font-size:13px;text-align:center;margin:20px 0 0;">
                ⏱ ينتهي خلال 5 دقائق | Expires in 5 minutes
              </p>
            </td>
          </tr>

          <!-- Security Notice -->
          <tr>
            <td style="padding:0 32px 32px;">
              <div style="background-color:rgba(239,68,68,0.1);border:1px solid rgba(239,68,68,0.2);border-radius:8px;padding:12px 16px;">
                <p style="color:#fca5a5;font-size:12px;margin:0;text-align:center;">
                  🔒 لا تشارك هذا الرمز مع أي شخص
                  <br/>
                  Do not share this code with anyone
                </p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:16px 32px 24px;text-align:center;">
              <p style="color:#475569;font-size:11px;margin:0;">
                هذا الرمز صالح لمرة واحدة فقط | This code is one-time use only
              </p>
              <p style="color:#334155;font-size:10px;margin:8px 0 0;">
                © 2026 Kasby Investment Platform
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${resendApiKey}`,
    },
    body: JSON.stringify({
      from: `Kasby <${fromEmail}>`,
      to: [email],
      subject: 'Kasby Verification Code — رمز التحقق من كاسبي',
      html: htmlBody,
    }),
  })

  const result = await response.json()
  if (!response.ok) {
    console.error('[send-otp] Resend Error:', result)
    throw new Error(`Email delivery failed: ${JSON.stringify(result)}`)
  }
  return result
}
