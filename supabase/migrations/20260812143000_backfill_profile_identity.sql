-- Backfill anagrafica da auth.users verso profiles (utenti già registrati)
update public.profiles p
set
  nome = case
    when coalesce(p.nome, '') = '' then coalesce(u.raw_user_meta_data->>'nome', '')
    else p.nome
  end,
  cognome = case
    when coalesce(p.cognome, '') = '' then coalesce(u.raw_user_meta_data->>'cognome', '')
    else p.cognome
  end,
  telefono = case
    when coalesce(p.telefono, '') = '' then coalesce(u.raw_user_meta_data->>'telefono', '')
    else p.telefono
  end,
  codice_fiscale = case
    when coalesce(p.codice_fiscale, '') = '' then coalesce(upper(u.raw_user_meta_data->>'codice_fiscale'), '')
    else p.codice_fiscale
  end
from auth.users u
where p.id = u.id;
