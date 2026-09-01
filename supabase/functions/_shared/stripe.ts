/** Minimal Stripe REST helper (form-urlencoded). */

export class StripeError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly body?: unknown,
  ) {
    super(message);
  }
}

function encodeForm(data: Record<string, string | number | undefined | null>): string {
  const parts: string[] = [];
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
  }
  return parts.join("&");
}

export async function stripeRequest<T = Record<string, unknown>>(
  secretKey: string,
  method: "GET" | "POST",
  path: string,
  form?: Record<string, string | number | undefined | null>,
): Promise<T> {
  const res = await fetch(`https://api.stripe.com/v1${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: method === "POST" ? encodeForm(form ?? {}) : undefined,
  });

  const json = await res.json();
  if (!res.ok) {
    const msg =
      (json as { error?: { message?: string } })?.error?.message ??
      "Errore Stripe";
    throw new StripeError(msg, res.status, json);
  }
  return json as T;
}

/** Verify Stripe webhook signature (v1). */
export async function verifyStripeWebhook(
  payload: string,
  signatureHeader: string,
  secret: string,
  toleranceSec = 300,
): Promise<boolean> {
  const parts = signatureHeader.split(",").map((p) => p.trim());
  let timestamp = "";
  const v1sigs: string[] = [];
  for (const part of parts) {
    const [k, v] = part.split("=");
    if (k === "t") timestamp = v;
    if (k === "v1") v1sigs.push(v);
  }
  if (!timestamp || v1sigs.length === 0) return false;

  const tsNum = Number(timestamp);
  if (!Number.isFinite(tsNum)) return false;
  const age = Math.abs(Math.floor(Date.now() / 1000) - tsNum);
  if (age > toleranceSec) return false;

  const signed = `${timestamp}.${payload}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signed),
  );
  const expected = Array.from(new Uint8Array(sigBuf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return v1sigs.some((sig) => timingSafeEqual(sig, expected));
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) {
    out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return out === 0;
}

export function eurosToCents(euros: number): number {
  return Math.round(euros * 100);
}

export function platformFeeCents(amountCents: number, bps: number): number {
  if (bps <= 0) return 0;
  return Math.max(0, Math.floor((amountCents * bps) / 10000));
}
