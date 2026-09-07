-- Fixes rejected products silently reappearing in the pending queue:
-- rejectProduct already deletes every store's `products` row for the
-- barcode, but a store that still has that item in local Stock (Isar) will
-- re-push a fresh `products` row the next time it touches that product at
-- all (a sale, a stock/price edit - ProductRepository.save/adjustStock
-- re-enqueue the full row on every edit), which silently resurrected the
-- barcode in pending_catalogue_items. This denylist makes rejection durable
-- regardless of what any store's local device does afterward, without
-- touching how any other (non-rejected) barcode flows through the queue.
create table public.rejected_catalogue_barcodes (
  barcode text primary key,
  rejected_at timestamptz not null default now(),
  rejected_by uuid references public.admin_users(id) on delete set null
);

alter table public.rejected_catalogue_barcodes enable row level security;
-- Deny-all, service-role only - same posture as audit_log/support_queries.
-- No anon/authenticated policy needed or wanted.

create or replace view public.pending_catalogue_items
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
and not exists (
  select 1 from public.rejected_catalogue_barcodes r where r.barcode = p.barcode
)
group by p.barcode;
