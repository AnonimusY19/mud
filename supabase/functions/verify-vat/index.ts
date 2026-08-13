// Verifica Partita IVA italiana via VIES + persistenza server-side + rate limit.
// Invocabile con anon key (pre-login).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const VIES_URL =
  "https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number";

const RATE_LIMIT_MAX = 12;
const RATE_LIMIT_WINDOW_MINUTES = 15;
const VERIFICATION_TTL_MINUTES = 30;

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

function normalizeVat(raw: string): string {
  let value = raw.trim().toUpperCase().replace(/[\s.]/g, "");
  if (value.startsWith("IT")) value = value.slice(2);
  return value;
}

function hasValidItalianCheckDigit(piva: string): boolean {
  let sum = 0;
  for (let i = 0; i < 10; i++) {
    let n = Number(piva[i]);
    if (i % 2 === 1) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  const check = (10 - (sum % 10)) % 10;
  return check === Number(piva[10]);
}

function validateItalianFormat(raw: string): string | null {
  const piva = normalizeVat(raw);
  if (!piva) return "Inserisci la Partita IVA";
  if (!/^\d{11}$/.test(piva)) return "La Partita IVA deve avere 11 cifre";
  if (!hasValidItalianCheckDigit(piva)) {
    return "Partita IVA non valida (cifra di controllo errata)";
  }
  return null;
}

function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? "";
  const first = fwd.split(",")[0]?.trim();
  return first || req.headers.get("cf-connecting-ip") || "unknown";
}

async function enforceRateLimit(
  admin: ReturnType<typeof createClient>,
  bucketKey: string,
): Promise<string | null> {
  const now = new Date();
  const { data: row } = await admin
    .from("edge_rate_limits")
    .select("bucket_key, window_start, hit_count")
    .eq("bucket_key", bucketKey)
    .maybeSingle();

  if (!row) {
    await admin.from("edge_rate_limits").upsert({
      bucket_key: bucketKey,
      window_start: now.toISOString(),
      hit_count: 1,
    });
    return null;
  }

  const windowStart = new Date(row.window_start);
  const elapsedMs = now.getTime() - windowStart.getTime();
  const windowMs = RATE_LIMIT_WINDOW_MINUTES * 60 * 1000;

  if (elapsedMs > windowMs) {
    await admin.from("edge_rate_limits").upsert({
      bucket_key: bucketKey,
      window_start: now.toISOString(),
      hit_count: 1,
    });
    return null;
  }

  if ((row.hit_count as number) >= RATE_LIMIT_MAX) {
    return "Troppe verifiche VIES. Riprova tra qualche minuto.";
  }

  await admin
    .from("edge_rate_limits")
    .update({ hit_count: (row.hit_count as number) + 1 })
    .eq("bucket_key", bucketKey);

  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ status: "error", message: "Metodo non consentito" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({
      status: "unavailable",
      message: "Configurazione server incompleta",
    }, 500);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const rateError = await enforceRateLimit(
    admin,
    `verify-vat:${clientIp(req)}`,
  );
  if (rateError) {
    return jsonResponse({ status: "unavailable", message: rateError }, 429);
  }

  let payload: { partitaIva?: string; vatNumber?: string; countryCode?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ status: "error", message: "Body JSON non valido" }, 400);
  }

  const raw = (payload.partitaIva ?? payload.vatNumber ?? "").toString();
  const countryCode = (payload.countryCode ?? "IT").toString().toUpperCase();

  if (countryCode !== "IT") {
    return jsonResponse({
      status: "invalid",
      message: "Al momento è supportata solo la Partita IVA italiana (IT)",
    });
  }

  const formatError = validateItalianFormat(raw);
  if (formatError) {
    return jsonResponse({ status: "invalid", message: formatError });
  }

  const vatNumber = normalizeVat(raw);

  try {
    const viesRes = await fetch(VIES_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({ countryCode: "IT", vatNumber }),
    });

    if (viesRes.status === 400) {
      return jsonResponse({
        status: "invalid",
        message: "Partita IVA non riconosciuta da VIES",
        vatNumber,
      });
    }

    if (!viesRes.ok) {
      return jsonResponse({
        status: "unavailable",
        message:
          `Servizio VIES non disponibile (HTTP ${viesRes.status}). Riprova tra poco.`,
        vatNumber,
      });
    }

    const data = await viesRes.json();
    const userError = (data?.userError as string | undefined)?.trim() ?? "";
    const userErrorUp = userError.toUpperCase();

    if (userError && userErrorUp !== "VALID" && userErrorUp !== "NONE") {
      if (
        userErrorUp.includes("UNAVAILABLE") ||
        userErrorUp.includes("TIMEOUT") ||
        userErrorUp.includes("MS_MAX")
      ) {
        return jsonResponse({
          status: "unavailable",
          message:
            "Archivio IVA italiano temporaneamente non raggiungibile via VIES. Riprova tra poco.",
          vatNumber,
        });
      }
      return jsonResponse({
        status: "invalid",
        message: `Partita IVA non valida secondo VIES (${userError})`,
        vatNumber,
      });
    }

    const valid = data?.valid === true || data?.isValid === true;
    if (!valid) {
      return jsonResponse({
        status: "invalid",
        message: "Partita IVA non attiva o non presente in VIES",
        vatNumber,
      });
    }

    const nameRaw = (data?.name as string | undefined)?.trim();
    const addressRaw = (data?.address as string | undefined)?.trim();
    const name = nameRaw && nameRaw !== "---" ? nameRaw : null;
    const address = addressRaw && addressRaw !== "---" ? addressRaw : null;
    const expiresAt = new Date(
      Date.now() + VERIFICATION_TTL_MINUTES * 60 * 1000,
    ).toISOString();

    const { data: verif, error: insertError } = await admin
      .from("vat_verifications")
      .insert({
        partita_iva: vatNumber,
        name,
        address,
        request_identifier: data?.requestIdentifier ?? null,
        expires_at: expiresAt,
      })
      .select("id")
      .single();

    if (insertError || !verif?.id) {
      console.error("vat_verifications insert error:", insertError);
      return jsonResponse({
        status: "unavailable",
        message: "Verifica VIES riuscita ma non salvata. Riprova.",
        vatNumber,
      }, 500);
    }

    return jsonResponse({
      status: "valid",
      vatNumber,
      countryCode: "IT",
      name,
      address,
      verificationId: verif.id,
      expiresAt,
      requestDate: data?.requestDate ?? null,
      requestIdentifier: data?.requestIdentifier ?? null,
    });
  } catch (error) {
    console.error("verify-vat VIES error:", error);
    return jsonResponse({
      status: "unavailable",
      message:
        "Impossibile contattare VIES. Controlla la connessione e riprova.",
      vatNumber,
    });
  }
});
