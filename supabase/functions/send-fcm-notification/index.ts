import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SendPushRequest {
  userId?: string;
  userIds?: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
  channelId?: string;
}

// Generates an OAuth2 access token using the Google Service Account private key
async function getGoogleOAuth2AccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const base64UrlEncode = (str: string) => {
    const bytes = new TextEncoder().encode(str);
    let binary = "";
    for (let i = 0; i < bytes.length; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary)
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const unsignedToken = `${encodedHeader}.${encodedClaimSet}`;

  // Parse PEM private key
  const pem = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");

  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsignedToken)
  );

  const signatureBytes = new Uint8Array(signatureBuffer);
  let signatureBinary = "";
  for (let i = 0; i < signatureBytes.length; i++) {
    signatureBinary += String.fromCharCode(signatureBytes[i]);
  }
  const encodedSignature = btoa(signatureBinary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${unsignedToken}.${encodedSignature}`;

  // Exchange JWT for OAuth2 Access Token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    const errText = await tokenResponse.text();
    throw new Error(`Google OAuth2 token exchange failed (${tokenResponse.status}): ${errText}`);
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ ok: false, error: "Server configuration missing (SUPABASE_URL/SERVICE_KEY)" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    const bodyText = await req.text();
    let payload: SendPushRequest;
    try {
      payload = JSON.parse(bodyText);
    } catch {
      return new Response(
        JSON.stringify({ ok: false, error: "Invalid JSON payload" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { userId, userIds, title, body, data, channelId } = payload;
    if (!title || !body) {
      return new Response(
        JSON.stringify({ ok: false, error: "Missing required fields: title and body are mandatory" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Aggregate recipient user IDs
    const targetUserIds = new Set<string>();
    if (userId) targetUserIds.add(userId);
    if (userIds && Array.isArray(userIds)) {
      userIds.forEach((id) => targetUserIds.add(id));
    }

    if (targetUserIds.size === 0) {
      return new Response(
        JSON.stringify({ ok: false, error: "No target userId or userIds specified" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Query active device tokens for the targeted users
    const { data: tokenRows, error: tokenQueryError } = await supabaseAdmin
      .from("user_device_tokens")
      .select("id, user_id, fcm_token")
      .in("user_id", Array.from(targetUserIds))
      .eq("is_active", true);

    if (tokenQueryError) {
      console.error("Failed to query device tokens:", tokenQueryError);
      return new Response(
        JSON.stringify({ ok: false, error: "Failed to retrieve device tokens" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!tokenRows || tokenRows.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          delivered: 0,
          message: "No active device registration tokens found for target recipient(s)",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check Firebase service account credentials in environment
    const rawServiceAccount =
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ||
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT_KEY");

    if (!rawServiceAccount) {
      console.log(
        `[FCM Push Delivery] Found ${tokenRows.length} active device token(s), but FIREBASE_SERVICE_ACCOUNT secret is not configured in Supabase. Skipping HTTP v1 push.`
      );
      return new Response(
        JSON.stringify({
          ok: true,
          delivered: 0,
          pendingTokens: tokenRows.length,
          skipped: true,
          notice:
            "Device tokens are registered, but FIREBASE_SERVICE_ACCOUNT secret is not yet configured in Supabase secrets. Please add the Firebase service account JSON key to enable live FCM push delivery.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let serviceAccount: { client_email: string; private_key: string; project_id: string };
    try {
      serviceAccount = JSON.parse(rawServiceAccount);
    } catch {
      console.error("Failed to parse FIREBASE_SERVICE_ACCOUNT JSON secret");
      return new Response(
        JSON.stringify({ ok: false, error: "FIREBASE_SERVICE_ACCOUNT secret is not valid JSON" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const projectId = serviceAccount.project_id;
    const accessToken = await getGoogleOAuth2AccessToken(serviceAccount);

    let deliveredCount = 0;
    const invalidTokens: string[] = [];

    // Send HTTP v1 message to each device token
    for (const row of tokenRows) {
      try {
        const messagePayload = {
          message: {
            token: row.fcm_token,
            notification: {
              title,
              body,
            },
            data: {
              ...(data || {}),
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
              priority: "high",
              notification: {
                channel_id: channelId || "report_updates_channel",
                sound: "default",
                notification_priority: "PRIORITY_HIGH",
                default_sound: true,
                default_vibrate_timings: true,
              },
            },
          },
        };

        const fcmRes = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify(messagePayload),
          }
        );

        if (fcmRes.ok) {
          deliveredCount++;
        } else {
          const errBody = await fcmRes.json().catch(() => ({}));
          const errorCode = errBody?.error?.details?.[0]?.errorCode || errBody?.error?.status;
          console.warn(`FCM delivery failed for token ${row.id}: ${fcmRes.status} ${errorCode}`);

          // Deactivate invalid / unregistered / expired tokens
          if (
            fcmRes.status === 404 ||
            errorCode === "UNREGISTERED" ||
            errorCode === "INVALID_ARGUMENT"
          ) {
            invalidTokens.push(row.fcm_token);
          }
        }
      } catch (fcmErr) {
        console.error(`FCM send exception for token ${row.id}:`, fcmErr);
      }
    }

    // Clean up defunct tokens if any
    if (invalidTokens.length > 0) {
      await supabaseAdmin.rpc("clean_invalid_fcm_tokens", {
        p_fcm_tokens: invalidTokens,
      });
      console.log(`Cleaned up ${invalidTokens.length} defunct FCM token(s).`);
    }

    return new Response(
      JSON.stringify({
        ok: true,
        delivered: deliveredCount,
        totalTokens: tokenRows.length,
        deactivatedTokens: invalidTokens.length,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Unknown error";
    console.error("send-fcm-notification unhandled error:", err);
    return new Response(
      JSON.stringify({ ok: false, error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
