-- Reverts 20260828120000: picking the latest submission made an
-- already-queued barcode look like it kept "re-appearing" every time a
-- different store added it, since its displayed name/category/mass would
-- flip on each new submission. The first submission's values are now
-- locked in for as long as the barcode sits in the queue; later
-- submissions from other stores only affect store_count.
create or replace view public.pending_catalogue_items as
select
  barcode,
  array_agg(distinct name) as name_variations,
  array_agg(distinct category) as category_variations,
  count(distinct store_id) as store_count,
  min(created_at) as first_submitted,
  (array_agg(name order by created_at asc))[1] as most_common_name,
  (array_agg(category order by created_at asc))[1] as most_common_category,
  (array_agg(mass order by created_at asc))[1] as most_common_mass
from public.products p
where not (exists (
  select 1 from public.catalogue_products cp where cp.barcode = p.barcode
))
group by barcode;
