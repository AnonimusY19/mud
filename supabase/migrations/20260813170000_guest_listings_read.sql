-- Lettura pubblica (anon) degli annunci per marketplace guest / preview.
-- Insert/update/delete restano solo authenticated + own rows.

drop policy if exists "Anon can view listings for marketplace" on public.listings;
create policy "Anon can view listings for marketplace"
  on public.listings
  for select
  to anon
  using (true);

grant select on table public.listings to anon;

-- Solo nome azienda (già security definer, campi minimi).
grant execute on function public.marketplace_company_names() to anon;
