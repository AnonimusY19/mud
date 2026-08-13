-- Campi fiscali azienda obbligatori in registrazione.

alter table public.profiles
  add column if not exists partita_iva text not null default '',
  add column if not exists codice_sdi text not null default '';

comment on column public.profiles.partita_iva is 'Partita IVA italiana (11 cifre)';
comment on column public.profiles.codice_sdi is 'Codice destinatario SDI (7 caratteri)';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tipo text;
begin
  v_tipo := coalesce(new.raw_user_meta_data->>'tipo_attivita', '');
  if v_tipo not in ('Fornitore', 'Acquirente') then
    v_tipo := 'Acquirente';
  end if;

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
    coalesce(new.raw_user_meta_data->>'partita_iva', ''),
    coalesce(upper(new.raw_user_meta_data->>'codice_sdi'), ''),
    v_tipo::public.activity_type,
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
