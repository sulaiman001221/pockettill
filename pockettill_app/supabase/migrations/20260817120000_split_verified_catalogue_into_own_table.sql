-- Separates the shared, admin-moderated catalogue from stores' own private
-- inventory. Previously a single `products` row did both jobs at once (a
-- store's own inventory line, and - if is_verified - the canonical
-- cross-store catalogue entry other stores' barcode lookups depended on).
-- That conflation is what forced the earlier release_verified_product
-- workaround (deleting a store's own product had to special-case verified
-- rows to avoid destroying shared data), and even that workaround had a gap:
-- a device's local "is this verified" copy never learns about a later
-- admin approval, so a stale-flag delete could still destroy catalogue data.
--
-- catalogue_products has no store_id/ownership at all, and only
-- service_role (DataMaster's admin actions) can write to it - a store's own
-- authenticated client has read-only access, structurally, not just by
-- convention. A store's own `products` table goes back to being purely
-- private data: always fully owned, always safely deletable.

create table public.catalogue_products (
  barcode text primary key,
  name text not null,
  mass text,
  category text,
  verified_at timestamptz not null default now(),
  -- Attribution only, not ownership - which store's submission this
  -- catalogue entry originated from, for admin reference. Never used to
  -- grant that store any special access to this row.
  submitted_by_store_id uuid references public.stores(uuid) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.catalogue_products enable row level security;

create policy catalogue_products_select on public.catalogue_products
  for select
  to authenticated
  using (true);

grant select on public.catalogue_products to authenticated;
grant all on public.catalogue_products to service_role;

-- Backfill existing verified products, keyed by barcode (pre-flight check
-- confirmed zero duplicate barcodes among currently-verified rows, so no
-- conflict-resolution logic is needed here).
insert into public.catalogue_products
  (barcode, name, mass, category, verified_at, submitted_by_store_id, created_at)
select
  barcode, name, mass, category, coalesce(verified_at, created_at), store_id, created_at
from public.products
where is_verified = true;

-- Drop everything that depends on products.is_verified before touching the
-- column itself.
drop view if exists public.pending_catalogue_items;
drop view if exists public.verified_catalogue_items;
drop policy if exists products_store_all on public.products;
drop policy if exists products_verified_catalogue on public.products;

-- products goes back to being purely private inventory. Pre-flight check
-- confirmed zero rows currently have a null store_id, so this NOT NULL is
-- safe to add back immediately.
alter table public.products alter column store_id set not null;
alter table public.products drop column is_verified;
alter table public.products drop column verified_at;

create policy products_store_all on public.products
  for all
  using (store_id = current_store_id())
  with check (store_id = current_store_id());

-- No longer needed - deleting a store's own product is a plain delete
-- again now that verified data lives in a structurally separate table.
drop function if exists public.release_verified_product(uuid);

-- Recreated against the new structure. "Pending" is now "a barcode some
-- store has in its own inventory that doesn't yet have a canonical
-- catalogue_products entry" - rather than a per-row flag, which also means
-- unverifying an entry (deleting it from catalogue_products) correctly
-- makes any store's existing submission for that barcode reappear here for
-- re-review, same as before.
create view public.pending_catalogue_items as
select
  p.barcode,
  array_agg(distinct p.name) as name_variations,
  array_agg(distinct p.category) as category_variations,
  count(distinct p.store_id) as store_count,
  min(p.created_at) as first_submitted,
  mode() within group (order by p.name) as most_common_name,
  mode() within group (order by p.category) as most_common_category,
  mode() within group (order by p.mass) as most_common_mass
from public.products p
where not exists (
  select 1 from public.catalogue_products cp where cp.barcode = p.barcode
)
group by p.barcode;

-- catalogue_products is already one row per barcode, so this is now a
-- straight passthrough rather than an aggregation.
create view public.verified_catalogue_items as
select barcode, name, category, mass, verified_at, submitted_by_store_id
from public.catalogue_products;

grant select on public.pending_catalogue_items to service_role;
grant select on public.verified_catalogue_items to service_role, authenticated;
