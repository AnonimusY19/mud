-- Seed: 5 account di test + 10 annunci ciascuno (categorie e città diverse)
-- Esegui in Supabase Dashboard → SQL Editor (ruolo postgres).
-- Gli utenti esistenti non vengono toccati.
-- Password comune a tutti: MudTest123!

create extension if not exists pgcrypto;

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
  v_password text := crypt('MudTest123!', gen_salt('bf'));
  u record;
  i int;
  v_cats text[] := array[
    'Alimentari', 'Elettronica', 'Abbigliamento', 'Materie Prime', 'Macchinari',
    'Servizi', 'Logistica', 'Altro', 'Alimentari', 'Elettronica'
  ];
  v_types text[] := array['Vendo', 'Cerco', 'Vendo', 'Vendo', 'Cerco', 'Vendo', 'Cerco', 'Vendo', 'Vendo', 'Cerco'];
  v_titles text[] := array[
    'Olio EVO biologico',
    'Sensori IoT industriali',
    'Tessuti cotone GOTS',
    'Granuli PET riciclato',
    'Tornio CNC usato',
    'Consulenza HACCP',
    'Trasporto refrigerato',
    'Stock imballaggi misti',
    'Farina di grano duro',
    'Monitor professionali 27"'
  ];
  v_units text[] := array['tanica 5L', 'pezzo', 'metro', 'kg', 'macchina', 'ora', 'km', 'bancale', 'kg', 'pezzo'];
  v_qty int[] := array[120, 40, 800, 5000, 2, 50, 0, 30, 2000, 15];
  v_prices numeric[] := array[48.00, 29.90, 7.50, 0.85, 12500.00, 65.00, 1.35, 22.00, 0.62, 189.00];
begin
  -- Tabella temporanea utenti seed
  create temporary table seed_users (
    idx int primary key,
    id uuid not null,
    email text not null,
    nome text not null,
    cognome text not null,
    telefono text not null,
    cf text not null,
    azienda text not null,
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
   'Rossi Foods Srl', 'Fornitore', 'Produzione e distribuzione alimentari tipici.',
   'Via Roma 10, Milano, MI, Italia', 'Via Roma', '10', 'Milano', 'MI', '20121', 'Lombardia', 45.4642, 9.1900),
  (2, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2', 'giulia.bianchi@mud.test', 'Giulia', 'Bianchi', '+393331000002', 'BNCGPP85C15F205E',
   'Bianchi Tech Spa', 'Acquirente', 'Acquisti componenti elettronici per produzione.',
   'Corso Buenos Aires 45, Milano, MI, Italia', 'Corso Buenos Aires', '45', 'Milano', 'MI', '20124', 'Lombardia', 45.4780, 9.2100),
  (3, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3', 'luca.verdi@mud.test', 'Luca', 'Verdi', '+393331000003', 'VRDPLA90D50L219V',
   'Verdi Logistics', 'Entrambi', 'Logistica e trading materie prime.',
   'Via dell''Indipendenza 20, Bologna, BO, Italia', 'Via dell''Indipendenza', '20', 'Bologna', 'BO', '40121', 'Emilia-Romagna', 44.4949, 11.3426),
  (4, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4', 'sara.neri@mud.test', 'Sara', 'Neri', '+393331000004', 'NRELCU88E41A662S',
   'Neri Fashion Lab', 'Fornitore', 'Abbigliamento e tessuti sostenibili.',
   'Via Tornabuoni 8, Firenze, FI, Italia', 'Via Tornabuoni', '8', 'Firenze', 'FI', '50123', 'Toscana', 43.7711, 11.2534),
  (5, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa5', 'paolo.bruno@mud.test', 'Paolo', 'Bruno', '+393331000005', 'FRNFRC75H12D612E',
   'Bruno Macchine Industriali', 'Entrambi', 'Macchinari e servizi di manutenzione.',
   'Via Po 15, Torino, TO, Italia', 'Via Po', '15', 'Torino', 'TO', '10123', 'Piemonte', 45.0650, 7.6910);

  for u in select * from seed_users order by idx loop
    -- Salta se l'email esiste già
    if exists (select 1 from auth.users where email = u.email) then
      raise notice 'Utente già presente, skip: %', u.email;
      continue;
    end if;

    insert into auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      phone,
      phone_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      confirmation_token,
      recovery_token,
      email_change_token_new,
      email_change
    ) values (
      v_instance_id,
      u.id,
      'authenticated',
      'authenticated',
      u.email,
      v_password,
      now(),
      u.telefono,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'nome', u.nome,
        'cognome', u.cognome,
        'telefono', u.telefono,
        'codice_fiscale', u.cf
      ),
      now(),
      now(),
      '',
      '',
      '',
      ''
    );

    insert into auth.identities (
      id,
      user_id,
      identity_data,
      provider,
      provider_id,
      last_sign_in_at,
      created_at,
      updated_at
    ) values (
      gen_random_uuid(),
      u.id,
      jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email',
      u.id::text,
      now(),
      now(),
      now()
    );

    -- Il trigger crea già il profilo base: aggiorniamo azienda + indirizzo strutturato
    update public.profiles
    set
      nome = u.nome,
      cognome = u.cognome,
      telefono = u.telefono,
      codice_fiscale = u.cf,
      nome_azienda = u.azienda,
      tipo_attivita = u.tipo,
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

    -- 10 annunci per utente, categorie/location diverse
    for i in 1..10 loop
      insert into public.listings (
        user_id,
        type,
        title,
        description,
        category,
        location,
        price,
        unit,
        quantity,
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
      ) values (
        u.id,
        v_types[i],
        v_titles[i] || ' — ' || u.azienda,
        'Annuncio di test #' || i || ' per ' || u.azienda || ' (' || v_cats[i] || ').',
        v_cats[i],
        case i
          when 1 then 'Via Dante 3, Milano, MI, Italia'
          when 2 then 'Via Toledo 50, Napoli, NA, Italia'
          when 3 then 'Via Garibaldi 12, Torino, TO, Italia'
          when 4 then 'Via Zamboni 22, Bologna, BO, Italia'
          when 5 then 'Via Condotti 18, Roma, RM, Italia'
          when 6 then 'Via Etnea 100, Catania, CT, Italia'
          when 7 then 'Via Sparano 7, Bari, BA, Italia'
          when 8 then 'Via XX Settembre 9, Genova, GE, Italia'
          when 9 then 'Via Mazzini 4, Verona, VR, Italia'
          else 'Via Maqueda 30, Palermo, PA, Italia'
        end,
        v_prices[i] + (u.idx * 0.10),
        v_units[i],
        v_qty[i],
        case i
          when 1 then 'Via Dante' when 2 then 'Via Toledo' when 3 then 'Via Garibaldi'
          when 4 then 'Via Zamboni' when 5 then 'Via Condotti' when 6 then 'Via Etnea'
          when 7 then 'Via Sparano' when 8 then 'Via XX Settembre' when 9 then 'Via Mazzini'
          else 'Via Maqueda'
        end,
        case i
          when 1 then '3' when 2 then '50' when 3 then '12' when 4 then '22' when 5 then '18'
          when 6 then '100' when 7 then '7' when 8 then '9' when 9 then '4' else '30'
        end,
        case i
          when 1 then 'Milano' when 2 then 'Napoli' when 3 then 'Torino' when 4 then 'Bologna' when 5 then 'Roma'
          when 6 then 'Catania' when 7 then 'Bari' when 8 then 'Genova' when 9 then 'Verona' else 'Palermo'
        end,
        case i
          when 1 then 'MI' when 2 then 'NA' when 3 then 'TO' when 4 then 'BO' when 5 then 'RM'
          when 6 then 'CT' when 7 then 'BA' when 8 then 'GE' when 9 then 'VR' else 'PA'
        end,
        case i
          when 1 then '20121' when 2 then '80134' when 3 then '10122' when 4 then '40126' when 5 then '00187'
          when 6 then '95131' when 7 then '70121' when 8 then '16121' when 9 then '37121' else '90133'
        end,
        case i
          when 1 then 'Lombardia' when 2 then 'Campania' when 3 then 'Piemonte' when 4 then 'Emilia-Romagna' when 5 then 'Lazio'
          when 6 then 'Sicilia' when 7 then 'Puglia' when 8 then 'Liguria' when 9 then 'Veneto' else 'Sicilia'
        end,
        'IT',
        case i
          when 1 then 45.4650 when 2 then 40.8518 when 3 then 45.0703 when 4 then 44.4949 when 5 then 41.9050
          when 6 then 37.5079 when 7 then 41.1250 when 8 then 44.4056 when 9 then 45.4384 else 38.1157
        end,
        case i
          when 1 then 9.1900 when 2 then 14.2681 when 3 then 7.6869 when 4 then 11.3426 when 5 then 12.4823
          when 6 then 15.0830 when 7 then 16.8667 when 8 then 8.9463 when 9 then 10.9916 else 13.3615
        end,
        'seed-listing-' || u.idx::text || '-' || i::text
      );
    end loop;

    raise notice 'Creato utente % con 10 annunci', u.email;
  end loop;
end $$;
