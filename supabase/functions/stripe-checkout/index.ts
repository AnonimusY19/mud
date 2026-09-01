// Crea ordine + Stripe Checkout Session (Connect destination charge).
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  eurosToCents,
  platformFeeCents,
  stripeRequest,
  StripeError,
} from "../_shared/stripe.ts";

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
  const feeBps = Number(Deno.env.get("STRIPE_PLATFORM_FEE_BPS") ?? "500");

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
  const buyerId = userData.user.id;

  let body: {
    listingId?: string;
    quantity?: number;
    streamChannelId?: string;
  } = {};
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "JSON non valido" }, 400);
  }

  const listingId = body.listingId?.trim();
  const quantity = Math.floor(Number(body.quantity ?? 1));
  const streamChannelId = body.streamChannelId?.trim() || null;

  if (!listingId) return jsonResponse({ error: "listingId richiesto" }, 400);
  if (!Number.isFinite(quantity) || quantity < 1) {
    return jsonResponse({ error: "quantity non valida" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { data: listing, error: listingError } = await admin
      .from("listings")
      .select("id, user_id, title, price, unit, quantity, type")
      .eq("id", listingId)
      .maybeSingle();

    if (listingError || !listing) {
      return jsonResponse({ error: "Annuncio non trovato" }, 404);
    }

    const sellerId = listing.user_id as string;
    if (sellerId === buyerId) {
      return jsonResponse({ error: "Non puoi pagare un tuo annuncio" }, 400);
    }

    const { data: seller, error: sellerError } = await admin
      .from("profiles")
      .select(
        "id, nome_azienda, stripe_account_id, stripe_charges_enabled",
      )
      .eq("id", sellerId)
      .maybeSingle();

    if (sellerError || !seller) {
      return jsonResponse({ error: "Venditore non trovato" }, 404);
    }
    if (!seller.stripe_account_id || !seller.stripe_charges_enabled) {
      return jsonResponse({
        error:
          "Il venditore non ha completato l'onboarding Stripe. Chiedigli di collegare i pagamenti dal profilo.",
        code: "seller_not_ready",
      }, 409);
    }

    const unitPriceCents = eurosToCents(Number(listing.price) || 0);
    if (unitPriceCents <= 0) {
      return jsonResponse({ error: "Prezzo annuncio non valido" }, 400);
    }

    const maxQty = Math.max(1, Number(listing.quantity) || 1);
    if (quantity > maxQty) {
      return jsonResponse({
        error: `Quantità massima disponibile: ${maxQty}`,
      }, 400);
    }

    const amountCents = unitPriceCents * quantity;
    const applicationFee = platformFeeCents(amountCents, feeBps);
    const title = String(listing.title ?? "Ordine MUD");

    const { data: order, error: orderError } = await admin
      .from("orders")
      .insert({
        listing_id: listingId,
        buyer_id: buyerId,
        seller_id: sellerId,
        stream_channel_id: streamChannelId,
        title,
        quantity,
        unit_price_cents: unitPriceCents,
        amount_cents: amountCents,
        currency: "eur",
        application_fee_cents: applicationFee,
        status: "pending_payment",
      })
      .select("*")
      .single();

    if (orderError || !order) {
      console.error("order insert:", orderError);
      return jsonResponse({ error: "Impossibile creare l'ordine" }, 500);
    }

    const unitLabel = (listing.unit as string)?.trim() || "pz";
    const redirectBase = `${supabaseUrl.replace(/\/$/, "")}/functions/v1/stripe-redirect`;
    const session = await stripeRequest<{
      id: string;
      url: string | null;
      payment_intent?: string;
    }>(stripeSecret, "POST", "/checkout/sessions", {
      mode: "payment",
      // Managed Payments (default su account nuovi) non supporta Connect + application_fee.
      "managed_payments[enabled]": "false",
      success_url:
        `${redirectBase}?kind=checkout-success&order_id=${order.id}`,
      cancel_url:
        `${redirectBase}?kind=checkout-cancel&order_id=${order.id}`,
      client_reference_id: order.id,
      "line_items[0][quantity]": quantity,
      "line_items[0][price_data][currency]": "eur",
      "line_items[0][price_data][unit_amount]": unitPriceCents,
      "line_items[0][price_data][product_data][name]": title.slice(0, 120),
      "line_items[0][price_data][product_data][description]":
        `${quantity} ${unitLabel} · MUD marketplace`,
      "payment_intent_data[application_fee_amount]": applicationFee,
      "payment_intent_data[transfer_data][destination]": seller.stripe_account_id,
      "payment_intent_data[metadata][order_id]": order.id,
      "payment_intent_data[metadata][listing_id]": listingId,
      "payment_intent_data[metadata][buyer_id]": buyerId,
      "payment_intent_data[metadata][seller_id]": sellerId,
      "metadata[order_id]": order.id,
      "metadata[listing_id]": listingId,
      "metadata[buyer_id]": buyerId,
      "metadata[seller_id]": sellerId,
    });

    if (!session.url) {
      await admin.from("orders").update({ status: "failed" }).eq("id", order.id);
      return jsonResponse({ error: "Checkout Session senza URL" }, 502);
    }

    await admin
      .from("orders")
      .update({
        stripe_checkout_session_id: session.id,
        stripe_payment_intent_id:
          typeof session.payment_intent === "string"
            ? session.payment_intent
            : null,
      })
      .eq("id", order.id);

    return jsonResponse({
      orderId: order.id,
      checkoutUrl: session.url,
      amountCents,
      currency: "eur",
      applicationFeeCents: applicationFee,
    });
  } catch (e) {
    if (e instanceof StripeError) {
      return jsonResponse({ error: e.message }, 502);
    }
    console.error("stripe-checkout error:", e);
    return jsonResponse({ error: "Errore interno stripe-checkout" }, 500);
  }
});
