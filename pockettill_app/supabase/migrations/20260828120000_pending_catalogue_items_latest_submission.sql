-- Was previously mode() (most frequent value) for name/category/mass shown
-- in the Verification Queue when multiple stores submit variations of the
-- same barcode. Admin feedback: the most recently submitted variation
-- should take priority instead, since it's more likely to reflect a
-- correction of an earlier typo than an older, more "popular" one.
create or replace view public.pending_catalogue_items as
select
  barcode,
  array_agg(distinct name) as name_variations,
  array_agg(distinct category) as category_variations,
  count(distinct store_id) as store_count,
  min(created_at) as first_submitted,
  (array_agg(name order by created_at desc))[1] as most_common_name,
  (array_agg(category order by created_at desc))[1] as most_common_category,
  (array_agg(mass order by created_at desc))[1] as most_common_mass
from public.products p
where not (exists (
  select 1 from public.catalogue_products cp where cp.barcode = p.barcode
))
group by barcode;
