-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260724221038). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.
--
-- NOTE: this migration's policies already reference current_store_id(),
-- which was created out-of-band before this ran - see
-- 20260718000000_reconstructed_rls_hardening.sql (that file's timestamp is
-- an estimate; the real order was: RLS hardening, then this migration).

create table if not exists public.returns (
  uuid uuid primary key,
  sale_uuid uuid not null,
  store_id uuid references public.stores(uuid),
  device_id text not null,
  reason text not null,
  stock_action text not null,
  resolution_type text not null,
  items_value numeric not null default 0,
  customer_owes numeric not null default 0,
  customer_receives numeric not null default 0,
  customer_id text,
  exchange_product_uuid uuid,
  exchange_product_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.return_items (
  uuid uuid primary key,
  return_uuid uuid not null,
  sale_uuid uuid not null,
  store_id uuid references public.stores(uuid),
  product_uuid uuid,
  product_name text not null,
  unit_price numeric not null,
  quantity integer not null
);

create index if not exists idx_returns_sale on public.returns (sale_uuid);
create index if not exists idx_return_items_sale on public.return_items (sale_uuid);
create index if not exists idx_return_items_return on public.return_items (return_uuid);

alter table public.returns enable row level security;
alter table public.return_items enable row level security;

create policy "returns_store_all" on public.returns
  for all using (store_id = current_store_id());

create policy "return_items_store_all" on public.return_items
  for all using (store_id = current_store_id());
