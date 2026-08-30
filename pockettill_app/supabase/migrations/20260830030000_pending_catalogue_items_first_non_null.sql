-- Refines 20260830020000: strict "first submission wins" per barcode meant
-- a later, more complete submission couldn't fill in a field the first
-- submission left blank (e.g. first store omits mass, second provides it —
-- the queue showed no mass at all). Each field now independently falls
-- back to the first non-null value in submission order, so name/category/
-- mass no longer all have to come from the same row.
create or replace view public.pending_catalogue_items as
select
  barcode,
  array_agg(distinct name) as name_variations,
  array_agg(distinct category) as category_variations,
  count(distinct store_id) as store_count,
  min(created_at) as first_submitted,
  (array_agg(name order by created_at asc) filter (where name is not null))[1] as most_common_name,
  (array_agg(category order by created_at asc) filter (where category is not null))[1] as most_common_category,
  (array_agg(mass order by created_at asc) filter (where mass is not null))[1] as most_common_mass
from public.products p
where not (exists (
  select 1 from public.catalogue_products cp where cp.barcode = p.barcode
))
group by barcode;
