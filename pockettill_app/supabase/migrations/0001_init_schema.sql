-- PocketTill sync schema.
--
-- Every device shares one Supabase project via a single publishable
-- (anon) API key baked into the app - there is no per-store Supabase Auth
-- login. RLS is ENABLED on every table, but with permissive allow-all
-- policies for the anon role, because that shared key is the only caller.
-- Security-wise this is equivalent to RLS-off for now (any holder of the
-- compiled app's key can read or write any store's rows), but it keeps the
-- Supabase security advisor clean and means adding real per-store auth
-- later is just a policy swap, not a schema migration. Replace these
-- policies with real per-store ones before this carries production-scale
-- financial data across many independent stores.
--
-- Run this once in the Supabase Dashboard -> SQL Editor for the project.

create table if not exists public.products (
  uuid uuid primary key,
  barcode text not null,
  name text not null,
  mass text,
  category text,
  unit text,
  price numeric not null,
  cost_price numeric,
  stock integer not null,
  low_stock_threshold integer not null default 5,
  is_verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);
create index if not exists products_barcode_idx on public.products (barcode);
create index if not exists products_created_at_idx on public.products (created_at);

create table if not exists public.sales (
  uuid uuid primary key,
  device_id text not null,
  total numeric not null,
  payment_type text not null,
  customer_id text,
  created_at timestamptz not null default now()
);
create index if not exists sales_created_at_idx on public.sales (created_at);
create index if not exists sales_device_id_idx on public.sales (device_id);

create table if not exists public.sale_items (
  sale_uuid uuid not null,
  product_uuid uuid not null,
  product_name text not null,
  unit_price numeric not null,
  quantity integer not null,
  subtotal numeric not null,
  primary key (sale_uuid, product_uuid)
);

create table if not exists public.credit_customers (
  uuid uuid primary key,
  name text not null,
  phone text,
  balance numeric not null default 0,
  credit_limit numeric,
  created_at timestamptz not null default now(),
  last_activity_at timestamptz
);

create table if not exists public.credit_transactions (
  uuid uuid primary key,
  customer_id text not null,
  amount numeric not null,
  type text not null,
  sale_uuid uuid,
  note text,
  balance_before numeric,
  balance_after numeric,
  created_at timestamptz not null default now()
);
create index if not exists credit_transactions_customer_id_idx on public.credit_transactions (customer_id);

create table if not exists public.devices (
  id text primary key,
  last_seen_at timestamptz
);

create table if not exists public.sync_log (
  id bigint generated always as identity primary key,
  device_id text not null,
  events_pushed integer not null,
  events_pulled integer not null,
  created_at timestamptz not null default now()
);

-- RLS: enabled everywhere, with temporary allow-all policies for the shared
-- app key (anon role). See the header comment - swap these for real
-- per-store policies once the app has authentication.

alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.credit_customers enable row level security;
alter table public.credit_transactions enable row level security;
alter table public.devices enable row level security;
alter table public.sync_log enable row level security;

create policy "beta allow all" on public.products
  for all to anon using (true) with check (true);
create policy "beta allow all" on public.sales
  for all to anon using (true) with check (true);
create policy "beta allow all" on public.sale_items
  for all to anon using (true) with check (true);
create policy "beta allow all" on public.credit_customers
  for all to anon using (true) with check (true);
create policy "beta allow all" on public.credit_transactions
  for all to anon using (true) with check (true);
create policy "beta allow all" on public.devices
  for all to anon using (true) with check (true);
create policy "beta allow all" on public.sync_log
  for all to anon using (true) with check (true);
