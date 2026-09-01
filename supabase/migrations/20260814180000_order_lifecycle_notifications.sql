-- Lifecycle ordini (dopo pagamento) + notifiche in-app.

-- 1) Nuovi stati ordine
alter table public.orders
  drop constraint if exists orders_status_check;

alter table public.orders
  add constraint orders_status_check check (status in (
    'draft',
    'pending_payment',
    'paid',
    'confirmed',
    'preparing',
    'shipped',
    'completed',
    'disputed',
    'cancelled',
    'refunded',
    'failed'
  ));

-- 2) Trigger pagamento: invariato nella sostanza (solo server → paid/refunded).
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

-- 3) Notifiche
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null default '',
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

create index if not exists notifications_user_unread_idx
  on public.notifications (user_id)
  where read_at is null;

alter table public.notifications enable row level security;

drop policy if exists "Users read own notifications" on public.notifications;
create policy "Users read own notifications"
on public.notifications for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications"
on public.notifications for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, update on public.notifications to authenticated;
revoke insert, delete on public.notifications from authenticated, anon;

create or replace function public.create_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  nid uuid;
begin
  insert into public.notifications (user_id, type, title, body, data)
  values (p_user_id, p_type, p_title, coalesce(p_body, ''), coalesce(p_data, '{}'::jsonb))
  returning id into nid;
  return nid;
end;
$$;

revoke all on function public.create_notification(uuid, text, text, text, jsonb) from public;
grant execute on function public.create_notification(uuid, text, text, text, jsonb) to service_role;

-- 4) Avanzamento stato ordine (buyer/seller)
create or replace function public.advance_order_status(
  p_order_id uuid,
  p_new_status text
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders;
  uid uuid := auth.uid();
  allowed boolean := false;
begin
  if uid is null then
    raise exception 'Non autenticato';
  end if;

  select * into o from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Ordine non trovato';
  end if;

  if uid <> o.buyer_id and uid <> o.seller_id then
    raise exception 'Non autorizzato';
  end if;

  -- Transizioni consentite
  if p_new_status = 'confirmed' and o.status = 'paid' and uid = o.seller_id then
    allowed := true;
  elsif p_new_status = 'preparing' and o.status = 'confirmed' and uid = o.seller_id then
    allowed := true;
  elsif p_new_status = 'shipped' and o.status = 'preparing' and uid = o.seller_id then
    allowed := true;
  elsif p_new_status = 'completed' and o.status = 'shipped' and uid = o.buyer_id then
    allowed := true;
  elsif p_new_status = 'disputed'
        and o.status in ('paid', 'confirmed', 'preparing', 'shipped')
        and (uid = o.buyer_id or uid = o.seller_id) then
    allowed := true;
  end if;

  if not allowed then
    raise exception 'Transizione non consentita: % → %', o.status, p_new_status;
  end if;

  update public.orders
  set status = p_new_status
  where id = p_order_id
  returning * into o;

  -- Notifiche alle parti
  if p_new_status = 'confirmed' then
    perform public.create_notification(
      o.buyer_id, 'order_confirmed', 'Ordine confermato',
      'Il venditore ha confermato: ' || o.title,
      jsonb_build_object('order_id', o.id)
    );
  elsif p_new_status = 'preparing' then
    perform public.create_notification(
      o.buyer_id, 'order_preparing', 'Ordine in preparazione',
      'Il venditore sta preparando: ' || o.title,
      jsonb_build_object('order_id', o.id)
    );
  elsif p_new_status = 'shipped' then
    perform public.create_notification(
      o.buyer_id, 'order_shipped', 'Ordine spedito',
      'Il venditore ha segnato come spedito: ' || o.title,
      jsonb_build_object('order_id', o.id)
    );
  elsif p_new_status = 'completed' then
    perform public.create_notification(
      o.seller_id, 'order_completed', 'Ordine completato',
      'Il compratore ha confermato la ricezione: ' || o.title,
      jsonb_build_object('order_id', o.id)
    );
  elsif p_new_status = 'disputed' then
    perform public.create_notification(
      case when uid = o.buyer_id then o.seller_id else o.buyer_id end,
      'order_disputed',
      'Disputa aperta',
      'È stata aperta una disputa su: ' || o.title,
      jsonb_build_object('order_id', o.id)
    );
  end if;

  return o;
end;
$$;

revoke all on function public.advance_order_status(uuid, text) from public;
grant execute on function public.advance_order_status(uuid, text) to authenticated;

-- 5) Helper: notifiche post-pagamento (chiamato dal webhook via SQL o service)
create or replace function public.notify_order_paid(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o public.orders;
  amount_txt text;
begin
  select * into o from public.orders where id = p_order_id;
  if not found then
    return;
  end if;

  amount_txt := to_char(o.amount_cents / 100.0, 'FM999999990.00') || ' €';

  perform public.create_notification(
    o.buyer_id,
    'order_paid',
    'Pagamento riuscito',
    'Hai pagato ' || amount_txt || ' per «' || o.title || '». Ricevuta disponibile in Ordini.',
    jsonb_build_object('order_id', o.id, 'role', 'buyer')
  );

  perform public.create_notification(
    o.seller_id,
    'order_paid',
    'Nuovo ordine pagato',
    'Hai ricevuto un ordine di ' || amount_txt || ' per «' || o.title || '». Confermalo in Ordini.',
    jsonb_build_object('order_id', o.id, 'role', 'seller')
  );
end;
$$;

revoke all on function public.notify_order_paid(uuid) from public;
grant execute on function public.notify_order_paid(uuid) to service_role;

create or replace function public.mark_notification_read(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = coalesce(read_at, now())
  where id = p_id and user_id = auth.uid();
end;
$$;

create or replace function public.mark_all_notifications_read()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.notifications
  set read_at = now()
  where user_id = auth.uid() and read_at is null;
end;
$$;

revoke all on function public.mark_notification_read(uuid) from public;
revoke all on function public.mark_all_notifications_read() from public;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;
