-- Seed the first Owner account for PocketTill DataMaster.
--
-- Step 1 — create the auth user via the Supabase Dashboard, NOT SQL:
--   Dashboard > Authentication > Users > Add user
--     - Email: sulaimanndlovu@gmail.com   (adjust if you want a different address)
--     - Password: set one you'll actually use to sign in
--     - Auto Confirm User: checked
--   (Creating auth.users rows by hand in SQL means hand-rolling the password
--   hash correctly — the Dashboard does this safely, so do it there.)
--
-- Step 2 — run this in the SQL Editor to grant that account Owner access
-- to the dashboard. Adjust the email and full_name if needed.

insert into public.admin_users (id, email, full_name, role, is_active)
select id, email, 'Sulaiman', 'owner', true
from auth.users
where email = 'sulaimanndlovu@gmail.com'
on conflict (id) do update
  set role = excluded.role,
      is_active = true;

-- Verify:
-- select * from public.admin_users;
