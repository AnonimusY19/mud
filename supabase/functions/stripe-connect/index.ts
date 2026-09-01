// Stripe Connect Express: onboarding venditore + stato account.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { stripeRequest, StripeError } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodo non consentito" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");

  if (!supabaseUrl || !anonKey || !serviceKey) {
    return jsonResponse({ error: "Configurazione Supabase incompleta" }, 500);
  }
  if (!stripeSecret) {
    return jsonResponse({ error: "STRIPE_SECRET_KEY non configurata" }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return jsonResponse({ error: "Authorization richiesta" }, 401);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Sessione non valida" }, 401);
  }
  const userId = userData.user.id;
  const email = userData.user.email ?? undefined;

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  let body: {
    action?: string;
    returnUrl?: string;
    refreshUrl?: string;
  } = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }
  const action = body.action ?? "status";

  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select(
      "id, nome_azienda, partita_iva, tipo_attivita, stripe_account_id, stripe_charges_enabled, stripe_details_submitted, stripe_onboarded_at",
    )
    .eq("id", userId)
    .maybeSingle();

  if (profileError || !profile) {
    return jsonResponse({ error: "Profilo non trovato" }, 404);
  }

  try {
    if (action === "status") {
      if (profile.stripe_account_id) {
        const account = await stripeRequest<{
          charges_enabled?: boolean;
          details_submitted?: boolean;
        }>(stripeSecret, "GET", `/accounts/${profile.stripe_account_id}`);

        const chargesEnabled = !!account.charges_enabled;
        const detailsSubmitted = !!account.details_submitted;
        await admin
          .from("profiles")
          .update({
            stripe_charges_enabled: chargesEnabled,
            stripe_details_submitted: detailsSubmitted,
            stripe_onboarded_at: chargesEnabled
              ? (profile.stripe_onboarded_at ?? new Date().toISOString())
              : profile.stripe_onboarded_at,
          })
          .eq("id", userId);

        return jsonResponse({
          stripeAccountId: profile.stripe_account_id,
          chargesEnabled,
          detailsSubmitted,
          ready: chargesEnabled,
        });
      }

      return jsonResponse({
        stripeAccountId: null,
        chargesEnabled: false,
        detailsSubmitted: false,
        ready: false,
      });
    }

    if (action === "onboard" || action === "refresh") {
      const tipo = String(profile.tipo_attivita ?? "");
      if (tipo === "Acquirente") {
        return jsonResponse({
          error:
            "Stripe Connect e disponibile solo per fornitori o profili misti (Entrambi)",
        }, 403);
      }

      let accountId = profile.stripe_account_id as string | null;

      if (!accountId) {
        const account = await stripeRequest<{ id: string }>(
          stripeSecret,
          "POST",
          "/accounts",
          {
            type: "express",
            country: "IT",
            email,
            "capabilities[card_payments][requested]": "true",
            "capabilities[transfers][requested]": "true",
            "business_profile[name]": profile.nome_azienda || undefined,
            "metadata[supabase_user_id]": userId,
            "metadata[partita_iva]": profile.partita_iva || undefined,
          },
        );
        accountId = account.id;
        await admin
          .from("profiles")
          .update({ stripe_account_id: accountId })
          .eq("id", userId);
      }

      // URL pubblici: Edge Function stripe-redirect (evita "requested path is invalid").
      const redirectBase =
        `${supabaseUrl.replace(/\/$/, "")}/functions/v1/stripe-redirect`;
      const returnUrl =
        (body.returnUrl && /^https?:\/\//i.test(body.returnUrl.trim())
          ? body.returnUrl.trim()
          : null) ??
        `${redirectBase}?kind=connect-return`;
      const refreshUrl =
        (body.refreshUrl && /^https?:\/\//i.test(body.refreshUrl.trim())
          ? body.refreshUrl.trim()
          : null) ??
        `${redirectBase}?kind=connect-refresh`;

      const link = await stripeRequest<{ url: string }>(
        stripeSecret,
        "POST",
        "/account_links",
        {
          account: accountId,
          type: "account_onboarding",
          refresh_url: refreshUrl,
          return_url: returnUrl,
        },
      );

      if (!link.url || !/^https?:\/\//i.test(link.url)) {
        return jsonResponse({
          error: "Stripe non ha restituito un URL di onboarding",
        }, 502);
      }

      return jsonResponse({
        url: link.url,
        stripeAccountId: accountId,
      });
    }

    return jsonResponse({ error: "Azione non valida" }, 400);
  } catch (e) {
    if (e instanceof StripeError) {
      return jsonResponse(
        { error: e.message },
        e.status >= 400 && e.status < 600 ? e.status : 502,
      );
    }
    console.error("stripe-connect error:", e);
    return jsonResponse({ error: "Errore interno stripe-connect" }, 500);
  }
});
