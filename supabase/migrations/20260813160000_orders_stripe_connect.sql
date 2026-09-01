-- Ordini marketplace + campi Stripe Connect sui profili.

-- 1) Campi Connect sul venditore (scritti solo da Edge Function / service_role).
alter table public.profiles
  add column if not exists stripe_account_id text,
  add column if not exists stripe_charges_enabled boolean not null default false,
  add column if not exists stripe_details_submitted boolean not null default false,
  add column if not exists stripe_onboarded_at timestamptz;

create unique index if not exists profiles_stripe_account_id_uidx
  on public.profiles (stripe_account_id)
  where stripe_account_id is not null;

create or replace function public.prevent_stripe_field_client_updates()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if coalesce(auth.role(), '') = 'service_role' then
      return new;
    end if;

    if old.stripe_account_id is distinct from new.stripe_account_id
       or old.stripe_charges_enabled is distinct from new.stripe_charges_enabled
       or old.stripe_details_submitted is distinct from new.stripe_details_submitted
       or old.stripe_onboarded_at is distinct from new.stripe_onboarded_at then
      raise exception 'I campi Stripe possono essere aggiornati solo dal server';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_lock_stripe_fields on public.profiles;
create trigger profiles_lock_stripe_fields
before update on public.profiles
for each row
execute function public.prevent_stripe_field_client_updates();

-- 2) Ordini
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete restrict,
  buyer_id uuid not null references auth.users (id) on delete restrict,
  seller_id uuid not null references auth.users (id) on delete restrict,
  stream_channel_id text,
  title text not null default '',
  quantity integer not null check (quantity > 0),
  unit_price_cents integer not null check (unit_price_cents >= 0),
  amount_cents integer not null check (amount_cents >= 0),
  currency text not null default 'eur',
  application_fee_cents integer not null default 0 check (application_fee_cents >= 0),
  status text not null default 'pending_payment'
    check (status in (
      'draft',
      'pending_payment',
      'paid',
      'cancelled',
      'refunded',
      'failed'
    )),
  stripe_checkout_session_id text,
  stripe_payment_intent_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  paid_at timestamptz,
  constraint orders_buyer_ne_seller check (buyer_id <> seller_id)
);

create index if not exists orders_buyer_idx on public.orders (buyer_id, created_at desc);
create index if not exists orders_seller_idx on public.orders (seller_id, created_at desc);
create index if not exists orders_listing_idx on public.orders (listing_id);
create index if not exists orders_status_idx on public.orders (status);
create unique index if not exists orders_checkout_session_uidx
  on public.orders (stripe_checkout_session_id)
  where stripe_checkout_session_id is not null;

create or replace function public.set_orders_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists orders_set_updated_at on public.orders;
create trigger orders_set_updated_at
before update on public.orders
for each row
execute function public.set_orders_updated_at();

-- Client: non può forzare stati finali / id Stripe.
create or replace function public.prevent_order_payment_tampering()
returns trigger
language plpgsql
as $$
begin
  if coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status not in ('draft', 'pending_payment') then
      raise exception 'Stato ordine non consentito in creazione';
    end if;
    if new.stripe_checkout_session_id is not null
       or new.stripe_payment_intent_id is not null
       or new.paid_at is not null then
      raise exception 'Campi Stripe non consentiti in creazione client';
    end if;
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from new.status
       and new.status in ('paid', 'refunded') then
      raise exception 'Transizione di pagamento solo dal server';
    end if;
    if old.stripe_checkout_session_id is distinct from new.stripe_checkout_session_id
       or old.stripe_payment_intent_id is distinct from new.stripe_payment_intent_id
       or old.paid_at is distinct from new.paid_at
       or old.amount_cents is distinct from new.amount_cents
       or old.application_fee_cents is distinct from new.application_fee_cents
       or old.buyer_id is distinct from new.buyer_id
       or old.seller_id is distinct from new.seller_id
       or old.listing_id is distinct from new.listing_id then
      raise exception 'Campi ordine protetti: solo il server può modificarli';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists orders_lock_payment_fields on public.orders;
create trigger orders_lock_payment_fields
before insert or update on public.orders
for each row
execute function public.prevent_order_payment_tampering();

alter table public.orders enable row level security;

drop policy if exists "Buyers and sellers can view own orders" on public.orders;
create policy "Buyers and sellers can view own orders"
on public.orders for select
to authenticated
using (auth.uid() = buyer_id or auth.uid() = seller_id);

-- Insert/update ordini solo via Edge Functions (service_role bypassa RLS).
-- Nessuna policy insert/update per authenticated.

grant select on public.orders to authenticated;
revoke insert, update, delete on public.orders from authenticated, anon;
