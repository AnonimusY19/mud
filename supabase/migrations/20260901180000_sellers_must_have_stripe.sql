-- Obbligo Stripe Connect per venditori (Fornitore/Entrambi) prima di pubblicare annunci.
-- Pulisce account venditori senza stripe_account_id.

-- 1) Cleanup: ordini → annunci → auth users (solo venditori senza Stripe)
do $$
declare
  victim uuid;
begin
  for victim in
    select p.id
    from public.profiles p
    where p.tipo_attivita in ('Fornitore', 'Entrambi')
      and (p.stripe_account_id is null or trim(p.stripe_account_id) = '')
  loop
    -- Notifiche
    delete from public.notifications where user_id = victim;

    -- Ordini (FK listings ON DELETE RESTRICT)
    delete from public.orders
    where buyer_id = victim or seller_id = victim;

    -- Annunci
    delete from public.listings where user_id = victim;

    -- Profilo (se non cascata da auth)
    delete from public.profiles where id = victim;

    -- Utente auth
    delete from auth.users where id = victim;
  end loop;
end;
$$;

-- 2) Gate insert annunci: venditori devono avere Stripe charges enabled
create or replace function public.require_stripe_for_seller_listings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  p record;
begin
  select tipo_attivita, stripe_account_id, stripe_charges_enabled
  into p
  from public.profiles
  where id = new.user_id;

  if not found then
    raise exception 'Profilo non trovato';
  end if;

  if p.tipo_attivita in ('Fornitore', 'Entrambi') then
    if p.stripe_account_id is null
       or trim(p.stripe_account_id) = ''
       or coalesce(p.stripe_charges_enabled, false) = false then
      raise exception
        'Collega Stripe Connect e completa l''onboarding prima di pubblicare annunci';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists listings_require_stripe_seller on public.listings;
create trigger listings_require_stripe_seller
before insert on public.listings
for each row
execute function public.require_stripe_for_seller_listings();

-- Policy insert più stretta (oltre al trigger): stesso vincolo via EXISTS
drop policy if exists "Users can insert own listings" on public.listings;
create policy "Users can insert own listings"
  on public.listings
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and (
      exists (
        select 1 from public.profiles pr
        where pr.id = auth.uid()
          and pr.tipo_attivita = 'Acquirente'
      )
      or exists (
        select 1 from public.profiles pr
        where pr.id = auth.uid()
          and pr.tipo_attivita in ('Fornitore', 'Entrambi')
          and pr.stripe_account_id is not null
          and trim(pr.stripe_account_id) <> ''
          and pr.stripe_charges_enabled = true
      )
    )
  );
