-- Seed: 3 account ACQUIRENTI (compratori) di test.
-- Esegui in Supabase Dashboard → SQL Editor (ruolo postgres).
-- Gli utenti già presenti (stessa email) vengono saltati.
--
-- Credenziali (password comune): MudBuyer123!
--   1) anna.compra@mud.test
--   2) marco.acquisto@mud.test
--   3) elena.buyer@mud.test

create extension if not exists pgcrypto;

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
  v_password text := crypt('MudBuyer123!', gen_salt('bf'));
  u record;
  v_vies_id uuid;
begin
  create temporary table seed_buyers (
    idx int primary key,
    id uuid not null,
    email text not null,
    nome text not null,
    cognome text not null,
    telefono text not null,
    cf text not null,
    azienda text not null,
    piva text not null,
    sdi text not null,
    descrizione text not null,
    localita text not null,
    street text not null,
    street_number text not null,
    city text not null,
    province text not null,
    postal_code text not null,
    region text not null,
    lat double precision not null,
    lng double precision not null
  ) on commit drop;

  insert into seed_buyers values
  (1, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1', 'anna.compra@mud.test', 'Anna', 'Compra', '+393341000001', 'CMPNNA85A41F205X',
   'Compra Retail Srl', '11134567001', 'BUY0001', 'Catena retail: acquisti alimentari e packaging.',
   'Via Torino 22, Milano, MI, Italia', 'Via Torino', '22', 'Milano', 'MI', '20123', 'Lombardia', 45.4580, 9.1800),
  (2, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2', 'marco.acquisto@mud.test', 'Marco', 'Acquisto', '+393341000002', 'CQSMRC78B12H501Y',
   'Acquisto Industriale Spa', '01234567002', 'BUY0002', 'Procurement componenti e materie prime.',
   'Via Mazzini 5, Verona, VR, Italia', 'Via Mazzini', '5', 'Verona', 'VR', '37121', 'Veneto', 45.4384, 10.9916),
  (3, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3', 'elena.buyer@mud.test', 'Elena', 'Buyer', '+393341000003', 'BYRLNE90C55H501Z',
   'Buyer Hub Srl', '01234567003', 'BUY0003', 'Marketplace buyer: elettronica e macchinari.',
   'Via Veneto 40, Roma, RM, Italia', 'Via Veneto', '40', 'Roma', 'RM', '00187', 'Lazio', 41.9080, 12.4890);

  for u in select * from seed_buyers order by idx loop
    if exists (select 1 from auth.users where email = u.email) then
      update public.profiles
      set
        nome = case when coalesce(trim(nome), '') = '' then u.nome else nome end,
        cognome = case when coalesce(trim(cognome), '') = '' then u.cognome else cognome end,
        telefono = u.telefono,
        nome_azienda = u.azienda,
        descrizione = u.descrizione,
        localita = u.localita,
        address = u.localita,
        street = u.street,
        street_number = u.street_number,
        city = u.city,
        province = u.province,
        postal_code = u.postal_code,
        region = u.region,
        country = 'IT',
        latitude = u.lat,
        longitude = u.lng,
        modalita = 'compra'
      where id = u.id;

      raise notice 'Compratore già presente, profilo aggiornato: %', u.email;
      continue;
    end if;

    insert into public.vat_verifications (partita_iva, name, expires_at)
    values (u.piva, u.azienda, now() + interval '1 day')
    returning id into v_vies_id;

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, phone, phone_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      v_instance_id, u.id, 'authenticated', 'authenticated', u.email, v_password,
      now(), u.telefono, now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'nome', u.nome,
        'cognome', u.cognome,
        'telefono', u.telefono,
        'codice_fiscale', u.cf,
        'nome_azienda', u.azienda,
        'partita_iva', u.piva,
        'codice_sdi', u.sdi,
        'tipo_attivita', 'Acquirente',
        'vies_verification_id', v_vies_id::text,
        'localita', u.localita,
        'address', u.localita,
        'street', u.street,
        'street_number', u.street_number,
        'city', u.city,
        'province', u.province,
        'postal_code', u.postal_code,
        'region', u.region,
        'country', 'IT',
        'latitude', u.lat::text,
        'longitude', u.lng::text,
        'place_id', 'seed-buyer-' || u.idx::text
      ),
      now(), now(), '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), u.id,
      jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email', u.id::text, now(), now(), now()
    );

    update public.profiles
    set
      nome = u.nome,
      cognome = u.cognome,
      telefono = u.telefono,
      codice_fiscale = u.cf,
      nome_azienda = u.azienda,
      partita_iva = u.piva,
      codice_sdi = u.sdi,
      descrizione = u.descrizione,
      localita = u.localita,
      address = u.localita,
      street = u.street,
      street_number = u.street_number,
      city = u.city,
      province = u.province,
      postal_code = u.postal_code,
      region = u.region,
      country = 'IT',
      latitude = u.lat,
      longitude = u.lng,
      place_id = 'seed-buyer-' || u.idx::text,
      modalita = 'compra'
    where id = u.id;

    raise notice 'Creato compratore % (%)', u.email, u.azienda;
  end loop;
end $$;
