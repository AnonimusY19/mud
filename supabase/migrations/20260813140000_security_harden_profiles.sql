-- Hardening sicurezza: profili, VIES server-side, rate limit edge.

-- 1) Non esporre più tutti i profili agli utenti autenticati.
drop policy if exists "Authenticated users can view profiles for marketplace" on public.profiles;

-- 2) RPC marketplace: crea se manca, poi solo authenticated (non anon).
create or replace function public.marketplace_company_names()
returns table (id uuid, nome_azienda text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, coalesce(p.nome_azienda, '') as nome_azienda
  from public.profiles p;
$$;

revoke all on function public.marketplace_company_names() from public;
revoke all on function public.marketplace_company_names() from anon;
grant execute on function public.marketplace_company_names() to authenticated;

-- 3) Audit verifica VIES (usata da Edge Function verify-vat).
create table if not exists public.vat_verifications (
  id uuid primary key default gen_random_uuid(),
  partita_iva text not null,
  name text,
  address text,
  request_identifier text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references auth.users (id) on delete set null
);

create index if not exists vat_verifications_piva_idx on public.vat_verifications (partita_iva);
create index if not exists vat_verifications_expires_idx on public.vat_verifications (expires_at);

alter table public.vat_verifications enable row level security;
-- Nessuna policy client: accesso solo via service_role (Edge Functions).

-- 4) Rate limit generico per Edge Functions.
create table if not exists public.edge_rate_limits (
  bucket_key text primary key,
  window_start timestamptz not null,
  hit_count integer not null default 0
);

alter table public.edge_rate_limits enable row level security;

-- 5) Marca verifica VIES sul profilo.
alter table public.profiles
  add column if not exists vies_verified_at timestamptz;

-- 6) Blocca modifica campi identità/fiscali dopo il primo valorizzamento.
create or replace function public.prevent_identity_field_changes()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if coalesce(trim(old.codice_fiscale), '') <> ''
       and old.codice_fiscale is distinct from new.codice_fiscale then
      raise exception 'Il codice fiscale non può essere modificato dopo la registrazione';
    end if;

    if coalesce(trim(old.partita_iva), '') <> ''
       and old.partita_iva is distinct from new.partita_iva then
      raise exception 'La Partita IVA non può essere modificata dopo la registrazione';
    end if;

    if coalesce(trim(old.codice_sdi), '') <> ''
       and old.codice_sdi is distinct from new.codice_sdi then
      raise exception 'Il codice SDI non può essere modificato dopo la registrazione';
    end if;

    if coalesce(trim(old.nome), '') <> ''
       and old.nome is distinct from new.nome then
      raise exception 'Il nome non può essere modificato dopo la registrazione';
    end if;

    if coalesce(trim(old.cognome), '') <> ''
       and old.cognome is distinct from new.cognome then
      raise exception 'Il cognome non può essere modificato dopo la registrazione';
    end if;

    -- vies_verified_at: solo valorizzabile, non azzerabile/alterabile a un altro timestamp arbitrario dal client
    if old.vies_verified_at is not null
       and old.vies_verified_at is distinct from new.vies_verified_at then
      raise exception 'Lo stato di verifica VIES non può essere modificato';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_lock_identity_fields on public.profiles;
create trigger profiles_lock_identity_fields
before update on public.profiles
for each row
execute function public.prevent_identity_field_changes();

-- 7) Signup: richiede verifica VIES recente e non consumata per la P.IVA dichiarata.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tipo text;
  v_piva text;
  v_vies_id uuid;
  v_verif record;
begin
  v_tipo := coalesce(new.raw_user_meta_data->>'tipo_attivita', '');
  if v_tipo not in ('Fornitore', 'Acquirente') then
    v_tipo := 'Acquirente';
  end if;

  v_piva := regexp_replace(
    upper(coalesce(new.raw_user_meta_data->>'partita_iva', '')),
    '[^0-9]',
    '',
    'g'
  );

  begin
    v_vies_id := nullif(new.raw_user_meta_data->>'vies_verification_id', '')::uuid;
  exception when others then
    raise exception 'Verifica VIES mancante o non valida';
  end;

  if v_piva = '' or v_vies_id is null then
    raise exception 'Registrazione richiede Partita IVA verificata con VIES';
  end if;

  select *
    into v_verif
  from public.vat_verifications
  where id = v_vies_id
  for update;

  if not found then
    raise exception 'Verifica VIES non trovata';
  end if;

  if v_verif.consumed_at is not null then
    raise exception 'Verifica VIES già utilizzata';
  end if;

  if v_verif.expires_at < now() then
    raise exception 'Verifica VIES scaduta: ripeti il controllo della Partita IVA';
  end if;

  if v_verif.partita_iva is distinct from v_piva then
    raise exception 'La Partita IVA non corrisponde alla verifica VIES';
  end if;

  update public.vat_verifications
  set consumed_at = now(), consumed_by = new.id
  where id = v_vies_id;

  insert into public.profiles (
    id,
    nome,
    cognome,
    telefono,
    codice_fiscale,
    nome_azienda,
    partita_iva,
    codice_sdi,
    tipo_attivita,
    vies_verified_at,
    localita,
    address,
    street,
    street_number,
    city,
    province,
    postal_code,
    region,
    country,
    latitude,
    longitude,
    place_id
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', ''),
    coalesce(new.raw_user_meta_data->>'cognome', ''),
    coalesce(new.raw_user_meta_data->>'telefono', ''),
    coalesce(upper(new.raw_user_meta_data->>'codice_fiscale'), ''),
    coalesce(new.raw_user_meta_data->>'nome_azienda', ''),
    v_piva,
    coalesce(upper(new.raw_user_meta_data->>'codice_sdi'), ''),
    v_tipo::public.activity_type,
    coalesce(v_verif.created_at, now()),
    coalesce(new.raw_user_meta_data->>'localita', ''),
    coalesce(new.raw_user_meta_data->>'address', new.raw_user_meta_data->>'localita', ''),
    coalesce(new.raw_user_meta_data->>'street', ''),
    coalesce(new.raw_user_meta_data->>'street_number', ''),
    coalesce(new.raw_user_meta_data->>'city', ''),
    coalesce(new.raw_user_meta_data->>'province', ''),
    coalesce(new.raw_user_meta_data->>'postal_code', ''),
    coalesce(new.raw_user_meta_data->>'region', ''),
    coalesce(new.raw_user_meta_data->>'country', ''),
    nullif(new.raw_user_meta_data->>'latitude', '')::double precision,
    nullif(new.raw_user_meta_data->>'longitude', '')::double precision,
    coalesce(new.raw_user_meta_data->>'place_id', '')
  );

  return new;
end;
$$;

-- Cleanup periodico verifiche scadute (opzionale, eseguibile a mano).
create or replace function public.cleanup_expired_vat_verifications()
returns integer
language sql
security definer
set search_path = public
as $$
  with deleted as (
    delete from public.vat_verifications
    where expires_at < now() - interval '1 day'
       or (consumed_at is not null and consumed_at < now() - interval '7 days')
    returning 1
  )
  select count(*)::integer from deleted;
$$;

revoke all on function public.cleanup_expired_vat_verifications() from public;
grant execute on function public.cleanup_expired_vat_verifications() to service_role;
