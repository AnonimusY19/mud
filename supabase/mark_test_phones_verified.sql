-- Marca come verificati i telefoni degli account di test (bypass OTP in locale/dev).
-- Esegui dopo seed_test_accounts.sql se gli utenti esistevano già senza phone_confirmed_at.

update auth.users u
set
  phone = coalesce(
    nullif(u.phone, ''),
    nullif(p.telefono, ''),
    nullif(u.raw_user_meta_data->>'telefono', '')
  ),
  phone_confirmed_at = coalesce(u.phone_confirmed_at, now())
from public.profiles p
where p.id = u.id
  and u.email like '%@mud.test';
