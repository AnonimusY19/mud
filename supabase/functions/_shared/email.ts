// Invio email opzionale via Resend (se RESEND_API_KEY è configurata).
export async function sendEmail(opts: {
  to: string;
  subject: string;
  html: string;
  text?: string;
}): Promise<{ sent: boolean; reason?: string }> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("RESEND_FROM_EMAIL") ?? "MUD <onboarding@resend.dev>";
  if (!apiKey) {
    return { sent: false, reason: "RESEND_API_KEY non configurata" };
  }
  if (!opts.to || !opts.to.includes("@")) {
    return { sent: false, reason: "destinatario non valido" };
  }

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [opts.to],
      subject: opts.subject,
      html: opts.html,
      text: opts.text ?? undefined,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    console.error("Resend error:", res.status, body);
    return { sent: false, reason: `Resend ${res.status}` };
  }
  return { sent: true };
}

export function orderPaidBuyerEmail(opts: {
  title: string;
  amountLabel: string;
  orderId: string;
}): { subject: string; html: string; text: string } {
  const subject = `Ricevuta pagamento · ${opts.title}`;
  const text =
    `Pagamento riuscito su MUD.\n\nAnnuncio: ${opts.title}\nImporto: ${opts.amountLabel}\nOrdine: ${opts.orderId}\n\nApri l'app → Ordini per i dettagli.`;
  const html = `
    <div style="font-family:system-ui,sans-serif;max-width:560px;margin:0 auto;color:#0F1B2D">
      <h1 style="font-size:20px">Pagamento riuscito</h1>
      <p>Grazie per il tuo acquisto su <strong>MUD</strong>.</p>
      <p><strong>Annuncio:</strong> ${escapeHtml(opts.title)}<br/>
      <strong>Importo:</strong> ${escapeHtml(opts.amountLabel)}<br/>
      <strong>Ordine:</strong> ${escapeHtml(opts.orderId)}</p>
      <p>Trovi lo stato aggiornato nella sezione <strong>Ordini</strong> dell'app.</p>
    </div>`;
  return { subject, html, text };
}

export function orderPaidSellerEmail(opts: {
  title: string;
  amountLabel: string;
  orderId: string;
}): { subject: string; html: string; text: string } {
  const subject = `Nuovo ordine pagato · ${opts.title}`;
  const text =
    `Hai un nuovo ordine su MUD.\n\nAnnuncio: ${opts.title}\nImporto: ${opts.amountLabel}\nOrdine: ${opts.orderId}\n\nApri Ordini e conferma l'ordine.`;
  const html = `
    <div style="font-family:system-ui,sans-serif;max-width:560px;margin:0 auto;color:#0F1B2D">
      <h1 style="font-size:20px">Nuovo ordine pagato</h1>
      <p>Un acquirente ha completato il pagamento su <strong>MUD</strong>.</p>
      <p><strong>Annuncio:</strong> ${escapeHtml(opts.title)}<br/>
      <strong>Importo:</strong> ${escapeHtml(opts.amountLabel)}<br/>
      <strong>Ordine:</strong> ${escapeHtml(opts.orderId)}</p>
      <p>Apri <strong>Ordini → Vendite</strong> e conferma l'ordine per avviare la preparazione.</p>
    </div>`;
  return { subject, html, text };
}

function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
