-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260724210142). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.
--
-- Current live definition of public.check_founding_store_qualification() -
-- adds an explicit ::integer cast on the last returned column.

create or replace function public.check_founding_store_qualification(store_uuid uuid)
returns table (
  qualified boolean,
  newly_qualified boolean,
  days_since_registration integer,
  sales_count integer,
  founding_stores_remaining integer
)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_store record;
  v_days integer;
  v_sales integer;
  v_newly_qualified boolean := false;
begin
  select * into v_store from public.stores where uuid = store_uuid;
  if not found then
    raise exception 'Store % not found', store_uuid;
  end if;

  v_days := greatest(0, extract(day from (now() - v_store.created_at))::integer);
  select count(*) into v_sales from public.sales where sales.store_id = store_uuid;

  if not v_store.is_beta_adopter
     and v_days >= 7
     and v_sales >= 5
     and public.is_founding_store() then
    update public.stores
    set is_beta_adopter = true,
        beta_joined_at = now(),
        qualification_checked_at = now(),
        qualification_sales_count = v_sales
    where uuid = store_uuid;
    v_newly_qualified := true;
  elsif not v_store.is_beta_adopter then
    update public.stores set qualification_checked_at = now() where uuid = store_uuid;
  end if;

  return query
    select
      (v_store.is_beta_adopter or v_newly_qualified),
      v_newly_qualified,
      v_days,
      v_sales,
      greatest(0, 100 - (select count(*) from public.stores where is_beta_adopter = true))::integer;
end;
$function$;
