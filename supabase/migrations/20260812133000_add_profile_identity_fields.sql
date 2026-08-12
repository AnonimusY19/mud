-- Identity fields collected at registration
alter table public.profiles
  add column if not exists nome text not null default '',
  add column if not exists cognome text not null default '',
  add column if not exists codice_fiscale text not null default '';

-- Populate personal fields from auth signup metadata
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
