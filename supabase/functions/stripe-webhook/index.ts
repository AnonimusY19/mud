// Webhook Stripe: pagamento completato + aggiornamento account Connect.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import {
  orderPaidBuyerEmail,
  orderPaidSellerEmail,
  sendEmail,
} from "../_shared/email.ts";
import { verifyStripeWebhook } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Metodo non consentito" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

  if (!supabaseUrl || !serviceKey) {
    return jsonResponse({ error: "Configurazione Supabase incompleta" }, 500);
  }
  if (!webhookSecret) {
    return jsonResponse({ error: "STRIPE_WEBHOOK_SECRET non configurata" }, 500);
  }

  const signature = req.headers.get("stripe-signature");
  if (!signature) {
    return jsonResponse({ error: "Firma Stripe mancante" }, 400);
  }

  const payload = await req.text();
  const valid = await verifyStripeWebhook(payload, signature, webhookSecret);
  if (!valid) {
    return jsonResponse({ error: "Firma Stripe non valida" }, 400);
  }

  let event: {
    type?: string;
    data?: { object?: Record<string, unknown> };
  };
  try {
    event = JSON.parse(payload);
  } catch {
    return jsonResponse({ error: "Payload non valido" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const type = event.type ?? "";
    const obj = event.data?.object ?? {};

    if (type === "checkout.session.completed") {
      const sessionId = obj.id as string | undefined;
      const orderId = (obj.metadata as Record<string, string> | undefined)
        ?.order_id ??
        (obj.client_reference_id as string | undefined);
      const paymentIntent = obj.payment_intent as string | undefined;
      const paymentStatus = obj.payment_status as string | undefined;

      if (paymentStatus === "paid" || paymentStatus === "no_payment_required") {
        let query = admin.from("orders").update({
          status: "paid",
          paid_at: new Date().toISOString(),
          stripe_payment_intent_id: paymentIntent ?? null,
          stripe_checkout_session_id: sessionId ?? null,
        });

        if (orderId) {
          query = query.eq("id", orderId);
        } else if (sessionId) {
          query = query.eq("stripe_checkout_session_id", sessionId);
        } else {
          return jsonResponse({ received: true, skipped: true });
        }

        const { data: updatedRows, error } = await query.select(
          "id, title, amount_cents, buyer_id, seller_id",
        );
        if (error) {
          console.error("webhook order update:", error);
          return jsonResponse({ error: "Update ordine fallito" }, 500);
        }

        const order = Array.isArray(updatedRows) ? updatedRows[0] : null;
        if (order?.id) {
          await admin.rpc("notify_order_paid", { p_order_id: order.id });

          const amountLabel =
            `${((order.amount_cents as number) / 100).toFixed(2)} €`;
          const title = String(order.title ?? "Ordine MUD");
          const oid = String(order.id);

          const [{ data: buyerAuth }, { data: sellerAuth }] = await Promise.all([
            admin.auth.admin.getUserById(String(order.buyer_id)),
            admin.auth.admin.getUserById(String(order.seller_id)),
          ]);

          const buyerEmail = buyerAuth.user?.email;
          const sellerEmail = sellerAuth.user?.email;

          if (buyerEmail) {
            const mail = orderPaidBuyerEmail({
              title,
              amountLabel,
              orderId: oid,
            });
            await sendEmail({
              to: buyerEmail,
              subject: mail.subject,
              html: mail.html,
              text: mail.text,
            });
          }
          if (sellerEmail) {
            const mail = orderPaidSellerEmail({
              title,
              amountLabel,
              orderId: oid,
            });
            await sendEmail({
              to: sellerEmail,
              subject: mail.subject,
              html: mail.html,
              text: mail.text,
            });
          }
        }
      }
    }

    if (type === "account.updated") {
      const accountId = obj.id as string | undefined;
      if (accountId) {
        const chargesEnabled = !!obj.charges_enabled;
        const detailsSubmitted = !!obj.details_submitted;
        await admin
          .from("profiles")
          .update({
            stripe_charges_enabled: chargesEnabled,
            stripe_details_submitted: detailsSubmitted,
            ...(chargesEnabled
              ? { stripe_onboarded_at: new Date().toISOString() }
              : {}),
          })
          .eq("stripe_account_id", accountId);
      }
    }

    if (
      type === "checkout.session.expired" ||
      type === "payment_intent.payment_failed"
    ) {
      const orderId = (obj.metadata as Record<string, string> | undefined)
        ?.order_id;
      const sessionId = obj.id as string | undefined;
      if (orderId || sessionId) {
        let query = admin
          .from("orders")
          .update({ status: "failed" })
          .eq("status", "pending_payment");
        if (orderId) query = query.eq("id", orderId);
        else if (sessionId) {
          query = query.eq("stripe_checkout_session_id", sessionId);
        }
        await query;
      }
    }

    if (type === "charge.refunded") {
      const paymentIntent = obj.payment_intent as string | undefined;
      if (paymentIntent) {
        await admin
          .from("orders")
          .update({ status: "refunded" })
          .eq("stripe_payment_intent_id", paymentIntent);
      }
    }

    return jsonResponse({ received: true });
  } catch (e) {
    console.error("stripe-webhook error:", e);
    return jsonResponse({ error: "Errore webhook" }, 500);
  }
});
