-- Lock tipo_attivita after signup: set from auth metadata, never changeable later.

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

  insert into public.profiles (id, nome, cognome, telefono, codice_fiscale, tipo_attivita)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nome', ''),
    coalesce(new.raw_user_meta_data->>'cognome', ''),
    coalesce(new.raw_user_meta_data->>'telefono', ''),
    coalesce(upper(new.raw_user_meta_data->>'codice_fiscale'), ''),
    v_tipo::public.activity_type
  );
  return new;
end;
$$;

create or replace function public.prevent_tipo_attivita_change()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' and old.tipo_attivita is distinct from new.tipo_attivita then
    raise exception 'Il tipo di attività non può essere modificato dopo la registrazione';
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_lock_tipo_attivita on public.profiles;
create trigger profiles_lock_tipo_attivita
before update on public.profiles
for each row
execute function public.prevent_tipo_attivita_change();
