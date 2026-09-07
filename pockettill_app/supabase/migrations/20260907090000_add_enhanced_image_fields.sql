alter table public.catalogue_products
  add column original_image_url text,
  add column is_image_enhanced boolean not null default false;

alter table public.stores
  add column use_catalogue_images boolean not null default true,
  add column images_wifi_only boolean not null default false;

-- New columns appended at the end, not inserted alongside their thematic
-- neighbours (image_url) - `create or replace view` rejects reordering
-- existing columns, only appending is allowed.
create or replace view public.verified_catalogue_items
with (security_invoker = true) as
select
  barcode,
  name,
  category,
  mass,
  image_url,
  verified_at,
  submitted_by_store_id,
  original_image_url,
  is_image_enhanced
from public.catalogue_products;
