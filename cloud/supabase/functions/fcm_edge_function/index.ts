// FILE: cloud/supabase/functions/fcm_edge_function/index.ts
// OWNER: DEV-04
// SAFETY: YES — SOS alert delivery
// WEEK: W1
// NOTE: Dùng Firebase HTTP v1 API (OAuth2 Service Account)
//       Legacy FCM_SERVER_KEY đã bị deprecated từ tháng 6/2024

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.9.1/mod.ts"

// ─── Tạo OAuth2 access token từ Service Account ───────────────────────────
async function getFirebaseAccessToken(): Promise<string> {
  const projectId   = Deno.env.get("FIREBASE_PROJECT_ID")!
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL")!
  // FIREBASE_PRIVATE_KEY lưu dạng PEM string với \n literal — cần unescape
  const privateKeyPem = Deno.env.get("FIREBASE_PRIVATE_KEY")!
    .replace(/\\n/g, "\n")

  // Import RSA private key
  const keyData = privateKeyPem
    .replace("-----BEGIN RSA PRIVATE KEY-----", "")
    .replace("-----END RSA PRIVATE KEY-----", "")
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  // Tạo JWT assertion theo Google OAuth2 spec
  const now = getNumericDate(0)
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: clientEmail,
      sub: clientEmail,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: getNumericDate(3600), // 1 giờ
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    },
    cryptoKey
  )

  // Đổi JWT lấy access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth2:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  })

  if (!tokenRes.ok) {
    const err = await tokenRes.text()
    throw new Error(`OAuth2 token exchange failed: ${err}`)
  }

  const tokenData = await tokenRes.json()
  return tokenData.access_token as string
}

// ─── Main Edge Function ────────────────────────────────────────────────────
serve(async (req: Request) => {
  try {
    const payload = await req.json()

    // Chỉ xử lý INSERT event trên sos_events
    if (payload.type !== "INSERT" || payload.table !== "sos_events") {
      return new Response("ignored", { status: 200 })
    }

    const sosEvent  = payload.record
    const deviceId: string = sosEvent.device_id
    const projectId = Deno.env.get("FIREBASE_PROJECT_ID")!

    // Lấy FCM token của Relap user được paired với T-Mod device này
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

    const profilesRes = await fetch(
      `${supabaseUrl}/rest/v1/profiles?linked_id=eq.${deviceId}&role=eq.relap&select=fcm_token`,
      {
        headers: {
          "apikey": supabaseKey,
          "Authorization": `Bearer ${supabaseKey}`,
        },
      }
    )

    if (!profilesRes.ok) {
      throw new Error(`Supabase profiles query failed: ${profilesRes.status}`)
    }

    const profiles = await profilesRes.json()

    if (!profiles || profiles.length === 0 || !profiles[0].fcm_token) {
      console.warn(`No relap FCM token found for device: ${deviceId}`)
      return new Response(
        JSON.stringify({ skipped: true, reason: "no_fcm_token", device_id: deviceId }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    const relapFcmToken: string = profiles[0].fcm_token

    // Lấy OAuth2 access token từ Service Account
    const accessToken = await getFirebaseAccessToken()

    // Gửi FCM push notification qua HTTP v1 API
    // Endpoint: /v1/projects/{projectId}/messages:send
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    const fcmPayload = {
      message: {
        token: relapFcmToken,                      // token thay vì "to" trong legacy API
        android: {
          priority: "HIGH",                         // HIGH thay vì "high" trong legacy
          notification: {
            title: "🚨 SOS — Cần trợ giúp ngay!",
            body: "Người thân của bạn đang gặp nguy hiểm",
            channel_id: "savicam_sos_channel",      // Android notification channel
            sound: "default",
          },
        },
        data: {                                     // data payload — tất cả là string
          type: "sos_alert",
          sos_event_id: sosEvent.id,
          device_id: deviceId,
          lat: String(sosEvent.lat),
          lng: String(sosEvent.lng),
          created_at: sosEvent.created_at,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
    }

    const fcmRes = await fetch(fcmEndpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,  // Bearer OAuth2 token, không phải "key="
      },
      body: JSON.stringify(fcmPayload),
    })

    const fcmResult = await fcmRes.json()

    if (!fcmRes.ok) {
      console.error("FCM v1 delivery failed:", JSON.stringify(fcmResult))
      return new Response(
        JSON.stringify({ error: "fcm_v1_failure", status: fcmRes.status, detail: fcmResult }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    }

    // HTTP v1 trả về { name: "projects/.../messages/..." } khi thành công
    console.log(`SOS FCM v1 sent successfully for device ${deviceId}:`, fcmResult.name)
    return new Response(
      JSON.stringify({ success: true, message_name: fcmResult.name }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )

  } catch (err) {
    console.error("Edge Function error:", err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})
