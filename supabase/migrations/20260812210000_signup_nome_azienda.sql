-- Include nome_azienda from signup metadata when creating profile.

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

  insert into public.profiles (id, nome, cognome, telefono, codice_fiscale, nome_azienda, tipo_attivita)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', ''),
    coalesce(new.raw_user_meta_data->>'cognome', ''),
    coalesce(new.raw_user_meta_data->>'telefono', ''),
    coalesce(upper(new.raw_user_meta_data->>'codice_fiscale'), ''),
    coalesce(new.raw_user_meta_data->>'nome_azienda', ''),
    v_tipo::public.activity_type
  );
  return new;
end;
$$;
