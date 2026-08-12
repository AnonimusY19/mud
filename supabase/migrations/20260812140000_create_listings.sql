-- Marketplace listings synced across devices

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null check (type in ('Vendo', 'Cerco')),
  title text not null,
  description text not null default '',
  category text not null default 'Altro',
  location text not null default '',
  price numeric(12, 2) not null default 0,
  unit text not null default '',
  quantity integer not null default 0,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index listings_user_id_idx on public.listings (user_id);
create index listings_type_idx on public.listings (type);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger listings_set_updated_at
before update on public.listings
for each row
execute function public.set_updated_at();

alter table public.listings enable row level security;

-- Tutti gli utenti autenticati vedono il marketplace
create policy "Authenticated users can view listings"
  on public.listings
  for select
  to authenticated
  using (true);

create policy "Users can insert own listings"
  on public.listings
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update own listings"
  on public.listings
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own listings"
  on public.listings
  for delete
  to authenticated
  using (auth.uid() = user_id);
