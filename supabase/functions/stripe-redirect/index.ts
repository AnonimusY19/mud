// Pagine HTML pubbliche per return/refresh Stripe (Connect + Checkout).
// Deploy: npx supabase functions deploy stripe-redirect --no-verify-jwt
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

function htmlPage(title: string, body: string): Response {
  const html = `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="utf-8" />
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title} - MUD</title>
  <style>
    body { font-family: system-ui, sans-serif; background:#0A1628; color:#F3F6FB;
      display:flex; min-height:100vh; align-items:center; justify-content:center; margin:0; padding:24px; }
    .card { max-width:480px; background:#122033; border:1px solid #2A3B55; border-radius:16px; padding:28px; }
    h1 { margin:0 0 12px; font-size:1.4rem; }
    p { margin:0 0 10px; color:#9CA8BC; line-height:1.45; }
    .ok { color:#22C55E; font-weight:700; }
  </style>
</head>
<body>
  <div class="card">
    <h1>${title}</h1>
    ${body}
  </div>
</body>
</html>`;

  // Body come bytes UTF-8 + Content-Type esplicito (evita text/plain / mojibake).
  return new Response(new TextEncoder().encode(html), {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

Deno.serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  const url = new URL(req.url);
  const kind = (url.searchParams.get("kind") ?? "").trim();

  switch (kind) {
    case "connect-return":
      return htmlPage(
        "Stripe collegato",
        `<p class="ok">Onboarding completato.</p>
         <p>Torna all'app <strong>MUD</strong>, apri <strong>Profilo</strong> e aggiorna lo stato Stripe se necessario.</p>
         <p>Puoi chiudere questa scheda.</p>`,
      );
    case "connect-refresh":
      return htmlPage(
        "Link scaduto",
        `<p>Il link di onboarding Stripe e scaduto o incompleto.</p>
         <p>Torna nell'app MUD &rarr; <strong>Profilo</strong> &rarr; <strong>Collega account Stripe</strong> e riprova.</p>`,
      );
    case "checkout-success":
      return htmlPage(
        "Pagamento riuscito",
        `<p class="ok">Il pagamento di test e andato a buon fine.</p>
         <p>Torna all'app MUD nella sezione <strong>Ordini</strong> per vedere lo stato aggiornato.</p>
         <p>Puoi chiudere questa scheda.</p>`,
      );
    case "checkout-cancel":
      return htmlPage(
        "Pagamento annullato",
        `<p>Hai annullato il Checkout Stripe.</p>
         <p>Torna alla chat in MUD se vuoi riprovare.</p>`,
      );
    default:
      return htmlPage(
        "MUD - Stripe",
        `<p>Pagina di ritorno Stripe.</p>
         <p>Apri l'app MUD per continuare.</p>`,
      );
  }
});
