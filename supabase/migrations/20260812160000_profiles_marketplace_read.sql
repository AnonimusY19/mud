-- Allow authenticated users to read profiles of other users (marketplace: company name, etc.)
-- NOTA: preferisci 20260812170000_marketplace_company_names.sql (espone solo nome_azienda).
-- Questa policy resta come fallback se usi join diretti su profiles.
drop policy if exists "Authenticated users can view profiles for marketplace" on public.profiles;
create policy "Authenticated users can view profiles for marketplace"
  on public.profiles
  for select
  to authenticated
  using (true);
