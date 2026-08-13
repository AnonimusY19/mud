// Token Stream Chat + upsert utenti (secret solo server-side).
// Richiede JWT utente autenticato.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64UrlEncode(data: string | Uint8Array): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function signHs256Jwt(
  secret: string,
  claims: Record<string, unknown>,
): Promise<string> {
  const header = base64UrlEncode(JSON.stringify({ alg: "HS256", typ: "JWT" }));
  const payload = base64UrlEncode(JSON.stringify(claims));
  const data = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(data),
  );
  return `${data}.${base64UrlEncode(new Uint8Array(signature))}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodo non consentito" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const streamApiKey = Deno.env.get("STREAM_API_KEY");
  const streamApiSecret = Deno.env.get("STREAM_API_SECRET");

  if (!supabaseUrl || !anonKey) {
    return jsonResponse({ error: "Configurazione Supabase incompleta" }, 500);
  }
  if (!streamApiKey || !streamApiSecret) {
    return jsonResponse({
      error:
        "STREAM_API_KEY / STREAM_API_SECRET non configurati nei secrets della Edge Function",
    }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Authorization richiesta" }, 401);
  }

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Sessione non valida" }, 401);
  }

  const userId = userData.user.id;

  let body: {
    action?: string;
    name?: string;
    image?: string;
    ensureUserId?: string;
    ensureName?: string;
    ensureImage?: string;
  } = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const action = (body.action ?? "token").toLowerCase();
  const now = Math.floor(Date.now() / 1000);

  try {
    if (action === "token") {
      const token = await signHs256Jwt(streamApiSecret, {
        user_id: userId,
        iat: now,
        exp: now + 60 * 60 * 24,
      });

      // Assicura che l'utente corrente esista su Stream.
      const serverToken = await signHs256Jwt(streamApiSecret, {
        server: true,
        iat: now,
        exp: now + 60 * 10,
      });
      const displayName = (body.name ?? "").toString().trim() || userId;
      await fetch(
        `https://chat.stream-io-api.com/users?api_key=${streamApiKey}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: serverToken,
            "Stream-Auth-Type": "jwt",
          },
          body: JSON.stringify({
            users: {
              [userId]: {
                id: userId,
                name: displayName,
                ...(body.image ? { image: body.image } : {}),
              },
            },
          }),
        },
      );

      return jsonResponse({
        apiKey: streamApiKey,
        token,
        userId,
      });
    }

    if (action === "ensure-user") {
      const ensureUserId = (body.ensureUserId ?? "").toString().trim();
      if (!ensureUserId || ensureUserId === userId) {
        return jsonResponse({ error: "ensureUserId non valido" }, 400);
      }
      // Solo UUID semplici (id profilo Supabase).
      if (!/^[0-9a-fA-F-]{36}$/.test(ensureUserId)) {
        return jsonResponse({ error: "ensureUserId formato non valido" }, 400);
      }

      const ensureName = (body.ensureName ?? "Utente").toString().trim().slice(0, 120) ||
        "Utente";
      const ensureImage = (body.ensureImage ?? "").toString().trim();

      const serverToken = await signHs256Jwt(streamApiSecret, {
        server: true,
        iat: now,
        exp: now + 60 * 10,
      });

      const upsertRes = await fetch(
        `https://chat.stream-io-api.com/users?api_key=${streamApiKey}`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: serverToken,
            "Stream-Auth-Type": "jwt",
          },
          body: JSON.stringify({
            users: {
              [ensureUserId]: {
                id: ensureUserId,
                name: ensureName,
                ...(ensureImage ? { image: ensureImage } : {}),
              },
            },
          }),
        },
      );

      if (!upsertRes.ok) {
        const text = await upsertRes.text();
        console.error("Stream ensure-user failed:", upsertRes.status, text);
        return jsonResponse({ error: "Impossibile preparare l'utente chat" }, 502);
      }

      return jsonResponse({ ok: true, userId: ensureUserId });
    }

    return jsonResponse({ error: "Azione non supportata" }, 400);
  } catch (error) {
    console.error("stream-token error:", error);
    return jsonResponse({ error: "Errore interno stream-token" }, 500);
  }
});
