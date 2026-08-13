# Edge Functions — MUD

## Secrets richiesti (Dashboard → Edge Functions → Secrets)

```bash
npx supabase secrets set STREAM_API_KEY=xxx STREAM_API_SECRET=yyy
```

`STREAM_API_SECRET` **non** deve più stare nel `.env` Flutter.

## Deploy

```bash
npx supabase db push   # o esegui le migration SQL in Dashboard
npx supabase functions deploy verify-vat
npx supabase functions deploy stream-token
```

## `verify-vat`

- Controlla formato P.IVA
- Chiama VIES
- Salva riga in `vat_verifications` e restituisce `verificationId`
- Rate limit: 12 req / 15 min per IP

## `stream-token`

- Richiede utente autenticato
- `action: token` → JWT Stream per l’utente corrente
- `action: ensure-user` → upsert interlocutore su Stream (senza secret in app)
