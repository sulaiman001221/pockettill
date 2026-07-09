-- PocketTill Supabase schema (Stage 3)
-- Run in the Supabase SQL editor. Idempotent-ish: uses IF NOT EXISTS/OR REPLACE
-- where possible, but is intended to be run once against a fresh project.

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Auth model (assumed, not enforced by any table in this file)
-- ---------------------------------------------------------------------------
-- Each physical device authenticates as its own Supabase Auth user, and its
-- `devices.id` is set equal to that user's `auth.uid()` when the device is
-- provisioned (provisioning itself happens out-of-band via service_role, not
-- through these RLS policies - see the `devices` policies below). Every
-- other table's "belongs to my store" check resolves the caller's store via
-- `auth_store_id()`, which looks up the device row matching `auth.uid()`.

-- ---------------------------------------------------------------------------
-- Tables (created in dependency order for FKs)
-- ---------------------------------------------------------------------------

create table if not exists stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_name text,
  owner_phone text,
  address text,
  is_beta_adopter boolean default false,
  beta_joined_at timestamptz,
  discount_rate numeric default 1.0,
  created_at timestamptz default now(),
  active boolean default true
);

create table if not exists devices (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id),
  device_name text,
  last_seen_at timestamptz,
  app_version text,
  created_at timestamptz default now()
);

create table if not exists credit_customers (
  id uuid primary key,
  store_id uuid references stores(id),
  name text not null,
  phone text,
  balance numeric default 0,
  created_at timestamptz not null,
  last_activity_at timestamptz
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  barcode text unique not null,
  name text not null,
  category text,
  unit text,
  created_by_store_id uuid references stores(id),
  is_verified boolean default false,
  created_at timestamptz default now()
);

create table if not exists store_products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id),
  product_id uuid references products(id),
  price numeric not null,
  current_stock int default 0,
  low_stock_threshold int default 5,
  updated_at timestamptz default now(),
  unique (store_id, product_id)
);

create table if not exists sales (
  id uuid primary key,
  store_id uuid references stores(id),
  device_id uuid references devices(id),
  total numeric not null,
  payment_type text not null,
  customer_id uuid references credit_customers(id),
  created_at timestamptz not null,
  synced_at timestamptz default now()
);

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid references sales(id),
  product_id uuid,
  product_name text not null,
  unit_price numeric not null,
  quantity int not null,
  subtotal numeric not null
);

create table if not exists credit_transactions (
  id uuid primary key,
  customer_id uuid references credit_customers(id),
  store_id uuid references stores(id),
  amount numeric not null,
  type text not null,
  sale_id uuid references sales(id),
  note text,
  created_at timestamptz not null
);

create table if not exists fee_settings (
  id uuid primary key default gen_random_uuid(),
  fee_type text,
  fee_value numeric,
  per_amount numeric,
  effective_from timestamptz,
  effective_to timestamptz,
  active boolean default false
);

create table if not exists platform_fees (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id),
  sale_id uuid references sales(id),
  sale_amount numeric,
  fee_amount numeric,
  deducted boolean default false,
  created_at timestamptz default now()
);

create table if not exists sync_log (
  id uuid primary key default gen_random_uuid(),
  device_id uuid references devices(id),
  synced_at timestamptz default now(),
  events_pushed int default 0,
  events_pulled int default 0
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

-- products(barcode) is already covered by the UNIQUE constraint above, which
-- Postgres backs with its own unique index - no separate index needed.
create index if not exists idx_sales_store_created on sales (store_id, created_at);
create index if not exists idx_sale_items_sale on sale_items (sale_id);
create index if not exists idx_credit_customers_store on credit_customers (store_id);
create index if not exists idx_credit_transactions_customer on credit_transactions (customer_id);
create index if not exists idx_sync_log_device on sync_log (device_id);

-- ---------------------------------------------------------------------------
-- Helper: resolve the calling device's store
-- ---------------------------------------------------------------------------

create or replace function auth_store_id()
returns uuid
language sql
stable
as $$
  select store_id from devices where id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table stores enable row level security;
alter table devices enable row level security;
alter table credit_customers enable row level security;
alter table products enable row level security;
alter table store_products enable row level security;
alter table sales enable row level security;
alter table sale_items enable row level security;
alter table credit_transactions enable row level security;
alter table fee_settings enable row level security;
alter table platform_fees enable row level security;
alter table sync_log enable row level security;

-- stores: read/update own row only. Provisioning (insert/delete) happens
-- server-side via service_role, which bypasses RLS entirely.
create policy "stores_select_own" on stores
  for select
  using (id = auth_store_id());

create policy "stores_update_own" on stores
  for update
  using (id = auth_store_id())
  with check (id = auth_store_id());

-- devices: read/update devices for the caller's own store. Device
-- provisioning (insert/delete) is server-side/admin only, same reasoning as
-- stores - a brand-new device has no existing devices row to resolve
-- auth_store_id() from.
create policy "devices_select_own_store" on devices
  for select
  using (store_id = auth_store_id());

create policy "devices_update_own_store" on devices
  for update
  using (store_id = auth_store_id())
  with check (store_id = auth_store_id());

-- credit_customers: full read/write scoped to the caller's own store.
create policy "credit_customers_all_own_store" on credit_customers
  for all
  using (store_id = auth_store_id())
  with check (store_id = auth_store_id());

-- credit_transactions: full read/write scoped to the caller's own store.
create policy "credit_transactions_all_own_store" on credit_transactions
  for all
  using (store_id = auth_store_id())
  with check (store_id = auth_store_id());

-- sales: full read/write scoped to the caller's own store.
create policy "sales_all_own_store" on sales
  for all
  using (store_id = auth_store_id())
  with check (store_id = auth_store_id());

-- sale_items: no store_id column of its own - scoped via the parent sale.
create policy "sale_items_all_own_store" on sale_items
  for all
  using (sale_id in (select id from sales where store_id = auth_store_id()))
  with check (sale_id in (select id from sales where store_id = auth_store_id()));

-- store_products: full read/write scoped to the caller's own store.
create policy "store_products_all_own_store" on store_products
  for all
  using (store_id = auth_store_id())
  with check (store_id = auth_store_id());

-- products: shared catalogue. Everyone authenticated can read every row and
-- contribute new rows; nobody in the `authenticated` role can ever touch
-- `is_verified` (moderation is admin/service_role only) - enforced at the
-- column-privilege level below, since RLS alone can't restrict which
-- columns an UPDATE/INSERT touches.
create policy "products_select_all" on products
  for select
  using (true);

create policy "products_insert_any" on products
  for insert
  with check (true);

create policy "products_update_any" on products
  for update
  using (true)
  with check (true);

revoke insert, update on products from authenticated;
grant insert (barcode, name, category, unit, created_by_store_id) on products to authenticated;
grant update (barcode, name, category, unit) on products to authenticated;

-- fee_settings: read-only for all authenticated users.
create policy "fee_settings_select_all" on fee_settings
  for select
  using (true);

-- platform_fees: no policies for `authenticated` at all - admin/service_role
-- only (service_role bypasses RLS by design, so it needs no explicit policy).

-- sync_log: each device can only see/write its own sync log rows.
create policy "sync_log_own_device" on sync_log
  for all
  using (device_id = auth.uid())
  with check (device_id = auth.uid());
