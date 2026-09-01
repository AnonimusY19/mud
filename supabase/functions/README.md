# Edge Functions — MUD

## Secrets richiesti

```bash
npx supabase secrets set STREAM_API_KEY=xxx STREAM_API_SECRET=yyy

# Stripe (test keys da Dashboard Stripe)
npx supabase secrets set \
  STRIPE_SECRET_KEY=sk_test_xxx \
  STRIPE_WEBHOOK_SECRET=whsec_xxx \
  STRIPE_PLATFORM_FEE_BPS=500 \
  APP_URL=https://YOUR_PROJECT_REF.supabase.co

# Email (opzionale, Resend) — ricevuta compratore + avviso nuovo ordine al venditore
npx supabase secrets set \
  RESEND_API_KEY=re_xxx \
  RESEND_FROM_EMAIL="MUD <noreply@tuodominio.it>"
```

`APP_URL` deve essere un URL **reale** `http(s)://...` (non `localhost:XXXX`).
Serve solo come return/refresh dopo Connect/Checkout; in sviluppo va bene l’URL del progetto Supabase.
Se manca o è invalido, `stripe-connect` usa in automatico `SUPABASE_URL`.

`STREAM_API_SECRET` e `STRIPE_SECRET_KEY` **non** devono stare nel `.env` Flutter.

Senza `RESEND_API_KEY` le email non partono, ma le **notifiche in-app** (tabella `notifications`) vengono comunque create al pagamento.

## Deploy

```bash
# SQL (Dashboard → SQL Editor oppure)
npx supabase db push

npx supabase functions deploy verify-vat
npx supabase functions deploy stream-token
npx supabase functions deploy stripe-connect
npx supabase functions deploy stripe-checkout
npx supabase functions deploy stripe-webhook --no-verify-jwt
npx supabase functions deploy stripe-redirect --no-verify-jwt
```

`stripe-redirect` serve le pagine HTML di ritorno dopo Connect/Checkout
(`?kind=connect-return|connect-refresh|checkout-success|checkout-cancel`).
**Obbligatorio** `--no-verify-jwt` perché Stripe apre l’URL nel browser senza token.

Il webhook Stripe deve chiamare:
`https://<PROJECT_REF>.supabase.co/functions/v1/stripe-webhook`

Eventi da ascoltare:
- `checkout.session.completed`
- `checkout.session.expired`
- `payment_intent.payment_failed`
- `account.updated`
- `charge.refunded`

## `verify-vat`

- Controlla formato P.IVA, chiama VIES, salva `vat_verifications`
- Rate limit: 12 req / 15 min per IP

## `stream-token`

- JWT Stream + ensure-user (secret solo server)

## `stripe-connect`

- `action: status` → stato account Express
- `action: onboard` → Account Link onboarding venditore

## `stripe-checkout`

- Crea `orders` + Checkout Session Connect (destination + application fee)
- Disabilita Managed Payments sulla sessione (`managed_payments[enabled]=false`) perché incompatibile con Connect
- Body: `{ listingId, quantity, streamChannelId? }`

## `stripe-webhook`

- Aggiorna ordine a `paid` / `failed` / `refunded`
- Crea notifiche in-app (`notify_order_paid`) per buyer e seller
- Invia email ricevuta/nuovo ordine se `RESEND_API_KEY` è impostata
- Sincronizza `stripe_charges_enabled` sul profilo venditore

## Ordini — lifecycle

Dopo `paid`, buyer/seller avanzano lo stato via RPC `advance_order_status`:

`paid → confirmed → preparing → shipped → completed` (+ `disputed`)

Migration: `20260814180000_order_lifecycle_notifications.sql`
