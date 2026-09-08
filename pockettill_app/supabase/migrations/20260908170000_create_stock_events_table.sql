-- Event-sourced stock changes for multi-device sync (replaces relying on
-- forced single-active-device logout to avoid conflicting stock writes -
-- see pockettill-pending-multidevice-event-sourcing memory / 2026-09-09
-- session for the full design). Stock level is the sum of quantity_delta
-- for a product, not a value any single device overwrites - two devices
-- selling the same product offline both land, instead of whichever syncs
-- last silently clobbering the other's sale.
create table public.stock_events (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(uuid),
  product_id uuid not null references public.products(uuid),
  device_id text not null,
  change_type text not null check (
    change_type in ('sale', 'restock', 'manual_adjustment', 'return', 'initial_stock')
  ),
  quantity_delta integer not null,
  reference_id uuid,
  created_at timestamptz not null,
  synced_at timestamptz not null default now()
);

create index stock_events_product_id_idx on public.stock_events(product_id);
create index stock_events_store_id_synced_at_idx on public.stock_events(store_id, synced_at);

alter table public.stock_events enable row level security;

-- Same store_id = current_store_id() "for all" pattern every other
-- store-scoped table uses.
create policy "stock_events_store_all"
on public.stock_events for all
using (store_id = current_store_id())
with check (store_id = current_store_id());

-- Realtime: other devices for the same store need to hear about a new
-- stock_events row live.
alter publication supabase_realtime add table public.stock_events;

-- Authoritative recompute path - not on the app's hot read path (each
-- device maintains products.stock as a running total, updated by applying
-- each delta exactly once), but the real source of truth for
-- reconciliation/debugging.
create or replace function public.get_product_stock(p_product_id uuid, p_store_id uuid)
returns integer
language sql
security invoker
set search_path = ''
as $$
  select coalesce(sum(quantity_delta), 0)::integer
  from public.stock_events
  where product_id = p_product_id and store_id = p_store_id;
$$;
