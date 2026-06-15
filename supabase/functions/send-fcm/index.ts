import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { JWT } from "npm:google-auth-library@9.6.3";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

// Note: Ensure FIREBASE_SERVICE_ACCOUNT is added to Supabase Secrets
// Command: supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * Validates the Authorization header.
 * Accepts:
 *   1. Supabase service_role JWT
 *   2. Valid authenticated user JWT (verified via Supabase Auth)
 *   3. Supabase anon key (for DB trigger calls)
 * 
 * Returns the role string or null if unauthorized.
 */
async function validateAuthorization(req: Request): Promise<{ role: string; userId?: string } | null> {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.replace('Bearer ', '').trim();
  if (!token) return null;

  const fcmSecret = Deno.env.get('FCM_SECRET') ?? '';

  // 1. Check if token matches service_role key or internal fcm_secret (used by DB triggers & internal calls)
  if (token === serviceRoleKey || token === fcmSecret) {
    return { role: 'service_role' };
  }

  // 3. Check if token is a valid user JWT
  if (token.includes('.') && token.length > 40) {
    try {
      const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
      const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
      if (!error && user) {
        return { role: 'authenticated', userId: user.id };
      }
    } catch (_) {
      // Token verification failed — fall through to rejection
    }
  }

  return null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ═══════════════════════════════════════════════
    // AUTHORIZATION CHECK — Reject unauthorized calls
    // ═══════════════════════════════════════════════
    const auth = await validateAuthorization(req);
    if (!auth) {
      console.error("[FCM] Unauthorized request rejected — missing or invalid Authorization header");
      return new Response(JSON.stringify({ success: false, error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401,
      });
    }

    const { token, title, body, data } = await req.json();

    // ═══════════════════════════════════════════════
    // PAYLOAD VALIDATION
    // ═══════════════════════════════════════════════
    if (!token || typeof token !== 'string' || token.length < 10) {
      throw new Error("Invalid or missing FCM token");
    }
    if (!title || typeof title !== 'string' || title.length > 500) {
      throw new Error("Invalid or missing title (max 500 chars)");
    }
    if (!body || typeof body !== 'string' || body.length > 2000) {
      throw new Error("Invalid or missing body (max 2000 chars)");
    }

    // Parse the service account from environment variables
    const serviceAccountVar = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountVar) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT env var not set");
    }

    const serviceAccount = JSON.parse(serviceAccountVar);

    // Initialize JWT client for Firebase messaging scope
    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });

    // Get the OAuth2 Access Token
    const tokens = await jwtClient.authorize();
    const accessToken = tokens.access_token;
    const projectId = serviceAccount.project_id;

    // Build the FCM payload
    const fcmPayload = {
      message: {
        token: token,
        notification: {
          title: title,
          body: body,
        },
        data: data || {},
        android: {
          priority: "high",
          notification: {
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      },
    };

    // Send the notification to FCM v1 API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const response = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(fcmPayload),
    });

    const fcmResponseStr = await response.text();

    if (!response.ok) {
      console.error("[FCM] FCM API Error:", fcmResponseStr);
      throw new Error(fcmResponseStr);
    }

    // ═══════════════════════════════════════════════
    // AUDIT LOG
    // ═══════════════════════════════════════════════
    console.log(`[FCM] ✓ Notification sent | role=${auth.role} | type=${data?.type || 'unknown'} | token=${token.substring(0, 12)}...`);

    return new Response(JSON.stringify({ success: true, message: "Notification sent successfully." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("[FCM] Error in send-fcm:", error);
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
