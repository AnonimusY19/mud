-- Marketplace: lettura pubblica del solo nome azienda (senza esporre tutto il profilo).
-- Preferibile a una policy SELECT illimitata su profiles.

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
grant execute on function public.marketplace_company_names() to authenticated;
grant execute on function public.marketplace_company_names() to anon;
