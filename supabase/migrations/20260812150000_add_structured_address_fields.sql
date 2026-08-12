-- Structured address fields for profiles and listings (non-destructive)

alter table public.profiles
  add column if not exists address text not null default '',
  add column if not exists street text not null default '',
  add column if not exists street_number text not null default '',
  add column if not exists city text not null default '',
  add column if not exists province text not null default '',
  add column if not exists postal_code text not null default '',
  add column if not exists region text not null default '',
  add column if not exists country text not null default '',
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists place_id text not null default '';

-- Backfill address from existing localita
update public.profiles
set address = localita
where coalesce(address, '') = '' and coalesce(localita, '') <> '';

alter table public.listings
  add column if not exists street text not null default '',
  add column if not exists street_number text not null default '',
  add column if not exists city text not null default '',
  add column if not exists province text not null default '',
  add column if not exists postal_code text not null default '',
  add column if not exists region text not null default '',
  add column if not exists country text not null default '',
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists place_id text not null default '';
