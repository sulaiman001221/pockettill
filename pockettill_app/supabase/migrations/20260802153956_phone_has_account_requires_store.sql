-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260802153956). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.
--
-- phone_has_account previously reported true for ANY auth.users row
-- matching the phone, including an orphaned registration that never
-- finished (verified/paid but createStore() failed or was never reached).
-- That permanently blocked re-registration for that number (since it's
-- "already registered") while login also permanently failed (no stores
-- row to select) - a dead end with no self-service recovery. Requiring a
-- matching stores row means an interrupted registration is correctly
-- treated as incomplete, so re-registering with that number resumes and
-- finishes it instead of being told it's taken.
create or replace function public.phone_has_account(check_phone text)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  return exists (
    select 1 from auth.users u
    join public.stores s on s.auth_user_id = u.id
    where u.phone = ltrim(check_phone, '+')
  );
end;
$function$;
