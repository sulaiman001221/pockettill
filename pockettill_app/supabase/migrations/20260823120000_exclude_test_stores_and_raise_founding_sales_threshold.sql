-- The 3 stores that exist right now are all test/dev accounts (the
-- founders' own testing, and the Play Store reviewer account), not real
-- users, and shouldn't count toward or occupy founding-store slots. Two
-- had already auto-qualified under the old 5-sale threshold from all the
-- testing this launch required - reverting that alongside excluding them
-- going forward.

alter table public.stores
  add column excluded_from_founding boolean not null default false;

update public.stores
set excluded_from_founding = true
where uuid in (
  'fcdf3369-defc-4c97-8dcb-c972b2ebab02',
  'ef9e5276-223c-445b-8c2a-2030a4f83556',
  'c642d2c6-9d74-4545-9503-5c9a81083402'
);

update public.stores
set is_beta_adopter = false,
    beta_joined_at = null,
    qualification_checked_at = null,
    qualification_sales_count = null
where uuid in (
  'fcdf3369-defc-4c97-8dcb-c972b2ebab02',
  'ef9e5276-223c-445b-8c2a-2030a4f83556'
);

create or replace function public.check_founding_store_qualification(store_uuid uuid)
 returns table(qualified boolean, newly_qualified boolean, days_since_registration integer, sales_count integer, founding_stores_remaining integer)
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
     and not v_store.excluded_from_founding
     and v_days >= 7
     and v_sales >= 50
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
