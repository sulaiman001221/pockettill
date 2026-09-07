-- Product photos: an Open Food Facts pull or an owner's own upload.
-- Nullable, purely additive - existing rows get NULL, nothing to backfill.
alter table public.products
  add column image_url text;

alter table public.catalogue_products
  add column image_url text;

drop view if exists public.pending_catalogue_items;
drop view if exists public.verified_catalogue_items;

-- Surface a representative image in the pending-review queue so admins can
-- see what they're approving, same "most common wins" pattern as the other
-- fields here. mode() ignores NULLs like every other aggregate, so a
-- barcode with no image submissions anywhere just yields NULL.
create view public.pending_catalogue_items
with (security_invoker = true) as
select
  p.barcode,
  array_agg(distinct p.name) as name_variations,
  array_agg(distinct p.category) as category_variations,
  count(distinct p.store_id) as store_count,
  min(p.created_at) as first_submitted,
  mode() within group (order by p.name) as most_common_name,
  mode() within group (order by p.category) as most_common_category,
  mode() within group (order by p.mass) as most_common_mass,
  mode() within group (order by p.image_url) as most_common_image_url
from public.products p
where not exists (
  select 1 from public.catalogue_products cp where cp.barcode = p.barcode
)
group by p.barcode;

create view public.verified_catalogue_items
with (security_invoker = true) as
select barcode, name, category, mass, image_url, verified_at, submitted_by_store_id
from public.catalogue_products;
