import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { JWT } from "npm:google-auth-library@9.6.3";

// Note: Ensure FIREBASE_SERVICE_ACCOUNT is added to Supabase Secrets
// Command: supabase secrets set FIREBASE_SERVICE_ACCOUNT='{"type":"service_account",...}'

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { token, title, body, data } = await req.json();

    if (!token || !title || !body) {
      throw new Error("Missing required parameters: token, title, body");
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
      console.error("FCM Error:", fcmResponseStr);
      throw new Error(fcmResponseStr);
    }

    return new Response(JSON.stringify({ success: true, message: "Notification sent successfully." }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (error) {
    console.error("Error in send-fcm:", error);
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});
