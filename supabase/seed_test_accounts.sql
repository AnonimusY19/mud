-- Seed: 5 account di test + 5 annunci ciascuno
-- Esegui in Supabase Dashboard → SQL Editor (ruolo postgres).
-- Gli utenti già presenti (stessa email) vengono saltati.
-- Password comune a tutti: MudTest123!

create extension if not exists pgcrypto;

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
  v_password text := crypt('MudTest123!', gen_salt('bf'));
  u record;
  i int;
  v_vies_id uuid;
  v_cats text[] := array['Alimentari', 'Elettronica', 'Abbigliamento', 'Materie Prime', 'Macchinari'];
  v_types text[] := array['Vendo', 'Cerco', 'Vendo', 'Vendo', 'Cerco'];
  v_titles text[] := array[
    'Olio EVO biologico',
    'Sensori IoT industriali',
    'Tessuti cotone GOTS',
    'Granuli PET riciclato',
    'Tornio CNC usato'
  ];
  v_units text[] := array['tanica 5L', 'pezzo', 'metro', 'kg', 'macchina'];
  v_qty int[] := array[120, 40, 800, 5000, 2];
  v_prices numeric[] := array[48.00, 29.90, 7.50, 0.85, 12500.00];
begin
  create temporary table seed_users (
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
    tipo public.activity_type not null,
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

  insert into seed_users values
  (1, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1', 'mario.rossi@mud.test', 'Mario', 'Rossi', '+393331000001', 'RSSMRA80A01H501U',
   'Rossi Foods Srl', '12345678903', 'MUD0001', 'Fornitore', 'Produzione e distribuzione alimentari tipici.',
   'Via Roma 10, Milano, MI, Italia', 'Via Roma', '10', 'Milano', 'MI', '20121', 'Lombardia', 45.4642, 9.1900),
  (2, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'giulia.bianchi@mud.test', 'Giulia', 'Bianchi', '+393331000002', 'BNCGPP85C15F205E',
   'Bianchi Tech Spa', '12345678903', 'MUD0002', 'Acquirente', 'Acquisti componenti elettronici per produzione.',
   'Corso Buenos Aires 45, Milano, MI, Italia', 'Corso Buenos Aires', '45', 'Milano', 'MI', '20124', 'Lombardia', 45.4780, 9.2100),
  (3, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'luca.verdi@mud.test', 'Luca', 'Verdi', '+393331000003', 'VRDPLA90D50L219V',
   'Verdi Logistics', '12345678903', 'MUD0003', 'Fornitore', 'Logistica e trading materie prime.',
   'Via dell''Indipendenza 20, Bologna, BO, Italia', 'Via dell''Indipendenza', '20', 'Bologna', 'BO', '40121', 'Emilia-Romagna', 44.4949, 11.3426),
  (4, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 'sara.neri@mud.test', 'Sara', 'Neri', '+393331000004', 'NRELCU88E41A662S',
   'Neri Fashion Lab', '12345678903', 'MUD0004', 'Fornitore', 'Abbigliamento e tessuti sostenibili.',
   'Via Tornabuoni 8, Firenze, FI, Italia', 'Via Tornabuoni', '8', 'Firenze', 'FI', '50123', 'Toscana', 43.7711, 11.2534),
  (5, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5', 'paolo.bruno@mud.test', 'Paolo', 'Bruno', '+393331000005', 'FRNFRC75H12D612E',
   'Bruno Macchine Industriali', '12345678903', 'MUD0005', 'Acquirente', 'Macchinari e servizi di manutenzione.',
   'Via Po 15, Torino, TO, Italia', 'Via Po', '15', 'Torino', 'TO', '10123', 'Piemonte', 45.0650, 7.6910);

  for u in select * from seed_users order by idx loop
    if exists (select 1 from auth.users where email = u.email) then
      -- Aggiorna comunque nome azienda / profilo (utile se seed già eseguito).
      -- Nota: campi fiscali già valorizzati restano bloccati dal trigger di sicurezza.
      update public.profiles
      set
        nome = case when coalesce(trim(nome), '') = '' then u.nome else nome end,
        cognome = case when coalesce(trim(cognome), '') = '' then u.cognome else cognome end,
        telefono = u.telefono,
        codice_fiscale = case when coalesce(trim(codice_fiscale), '') = '' then u.cf else codice_fiscale end,
        nome_azienda = u.azienda,
        partita_iva = case when coalesce(trim(partita_iva), '') = '' then u.piva else partita_iva end,
        codice_sdi = case when coalesce(trim(codice_sdi), '') = '' then u.sdi else codice_sdi end,
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
        longitude = u.lng
      where id = u.id;

      update public.listings l
      set title = regexp_replace(l.title, ' — ' || u.azienda || '$', '')
      where l.user_id = u.id
        and l.title like '% — ' || u.azienda;

      raise notice 'Utente già presente, aggiornato profilo/titoli: %', u.email;
      continue;
    end if;

    -- Verifica VIES fittizia per soddisfare handle_new_user (solo seed).
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
        'tipo_attivita', u.tipo::text,
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
        'place_id', 'seed-' || u.idx::text
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

    -- Trigger ha creato il profilo: completa azienda + indirizzo (senza cambiare tipo_attivita)
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
      place_id = 'seed-' || u.idx::text,
      modalita = 'compra'
    where id = u.id;

    for i in 1..5 loop
      insert into public.listings (
        user_id, type, title, description, category, location,
        price, unit, quantity,
        street, street_number, city, province, postal_code, region, country,
        latitude, longitude, place_id
      ) values (
        u.id,
        v_types[i],
        v_titles[i],
        'Annuncio di test #' || i || ' per ' || u.azienda || ' (' || v_cats[i] || ').',
        v_cats[i],
        case i
          when 1 then 'Via Dante 3, Milano, MI, Italia'
          when 2 then 'Via Toledo 50, Napoli, NA, Italia'
          when 3 then 'Via Garibaldi 12, Torino, TO, Italia'
          when 4 then 'Via Zamboni 22, Bologna, BO, Italia'
          else 'Via Condotti 18, Roma, RM, Italia'
        end,
        v_prices[i] + (u.idx * 0.10),
        v_units[i],
        v_qty[i],
        case i when 1 then 'Via Dante' when 2 then 'Via Toledo' when 3 then 'Via Garibaldi' when 4 then 'Via Zamboni' else 'Via Condotti' end,
        case i when 1 then '3' when 2 then '50' when 3 then '12' when 4 then '22' else '18' end,
        case i when 1 then 'Milano' when 2 then 'Napoli' when 3 then 'Torino' when 4 then 'Bologna' else 'Roma' end,
        case i when 1 then 'MI' when 2 then 'NA' when 3 then 'TO' when 4 then 'BO' else 'RM' end,
        case i when 1 then '20121' when 2 then '80134' when 3 then '10122' when 4 then '40126' else '00187' end,
        case i when 1 then 'Lombardia' when 2 then 'Campania' when 3 then 'Piemonte' when 4 then 'Emilia-Romagna' else 'Lazio' end,
        'IT',
        case i when 1 then 45.4650 when 2 then 40.8518 when 3 then 45.0703 when 4 then 44.4949 else 41.9050 end,
        case i when 1 then 9.1900 when 2 then 14.2681 when 3 then 7.6869 when 4 then 11.3426 else 12.4823 end,
        'seed-listing-' || u.idx::text || '-' || i::text
      );
    end loop;

    raise notice 'Creato utente % (%) con 5 annunci', u.email, u.azienda;
  end loop;
end $$;
