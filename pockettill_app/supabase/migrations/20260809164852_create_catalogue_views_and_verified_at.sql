alter table public.products add column if not exists verified_at timestamptz;

create or replace view public.pending_catalogue_items
with (security_invoker = true) as
select
  barcode,
  array_agg(distinct name) as name_variations,
  array_agg(distinct category) as category_variations,
  count(distinct store_id) as store_count,
  min(created_at) as first_submitted,
  mode() within group (order by name) as most_common_name,
  mode() within group (order by category) as most_common_category,
  mode() within group (order by mass) as most_common_mass
from public.products
where is_verified = false
group by barcode;

create or replace view public.verified_catalogue_items
with (security_invoker = true) as
select
  barcode,
  mode() within group (order by name) as name,
  mode() within group (order by category) as category,
  mode() within group (order by mass) as mass,
  max(verified_at) as verified_at,
  count(distinct store_id) as store_count
from public.products
where is_verified = true
group by barcode;
