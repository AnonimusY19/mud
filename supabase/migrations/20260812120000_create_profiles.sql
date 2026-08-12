-- Profiles linked 1:1 to auth.users (all ProfileScreen fields)

create type public.activity_type as enum ('Fornitore', 'Acquirente', 'Entrambi');
create type public.app_mode as enum ('compra', 'vendi');

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null default '',
  cognome text not null default '',
  codice_fiscale text not null default '',
  nome_azienda text not null default '',
  tipo_attivita public.activity_type not null default 'Entrambi',
  descrizione text not null default '',
  localita text not null default '',
  telefono text not null default '',
  logo_url text,
  modalita public.app_mode not null default 'compra',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

-- Auto-create profile when a user signs up (personal fields from metadata)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nome, cognome, telefono, codice_fiscale)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', ''),
    coalesce(new.raw_user_meta_data->>'cognome', ''),
    coalesce(new.raw_user_meta_data->>'telefono', ''),
    coalesce(upper(new.raw_user_meta_data->>'codice_fiscale'), '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles
  for select
  to authenticated
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles
  for insert
  to authenticated
  with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles
  for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);
