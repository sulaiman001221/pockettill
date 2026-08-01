-- RECONSTRUCTED MIGRATION - read before touching.
--
-- Unlike every other file in this folder, this one was NOT applied through
-- Supabase's tracked migration system (`supabase_migrations.schema_migrations`
-- has no entry for it) - it was run directly against the live project via
-- ad-hoc SQL in an earlier session, and never saved to the repo. This file
-- reconstructs that SQL from the live database's actual current state
-- (pg_proc + pg_policies), captured on 2026-07-31.
--
-- The 20260718000000 timestamp is an ESTIMATE, not a real applied-at time -
-- it only had to land somewhere after 20260714192203
-- (extend_beta_policies_to_authenticated, which still references the old
-- "beta allow all" policies) and before 20260724221038 (add_returns_tables,
-- whose policies already call current_store_id()). The true date is unknown.
--
-- DO NOT run this against the jaiaolofdxtsbbsyjvio project - every object
-- below already exists there exactly as written. This file exists purely so
-- the repo has a record of it and so a FRESH project can be bootstrapped to
-- the same state from these files alone.
--
-- What this does: replaces the Stage 12 "beta allow all" policies (shared
-- anon/authenticated key, no real isolation) with genuine per-store RLS,
-- keyed off the caller's Supabase Auth session via a new
-- current_store_id() helper, and locks down the `stores` table itself
-- (previously RLS was enabled but had no policies as of the stage13
-- migration - the app's `beta_allow_all_policies`-era comment noting "RLS
-- stays OFF for stores" was already stale by the time this ran).

-- ---------------------------------------------------------------------------
-- Helper: resolve the calling session's own store
-- ---------------------------------------------------------------------------

create or replace function public.current_store_id()
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  select uuid from public.stores
  where auth_user_id = auth.uid()
  limit 1;
$function$;

-- ---------------------------------------------------------------------------
-- stores: lock to the owning auth user
-- ---------------------------------------------------------------------------

alter table public.stores enable row level security;

create policy "stores_select" on public.stores
  for select using (auth_user_id = auth.uid());

create policy "stores_insert" on public.stores
  for insert with check (auth_user_id = auth.uid());

create policy "stores_update" on public.stores
  for update using (auth_user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Swap "beta allow all" for real per-store policies
-- ---------------------------------------------------------------------------

drop policy if exists "beta allow all" on public.products;
create policy "products_store_all" on public.products
  for all using (store_id = current_store_id());
-- products doubles as the shared cross-store catalogue - every
-- authenticated/anon caller can still read a verified row regardless of
-- which store owns it (needed for barcode-scan autofill), on top of the
-- store-scoped policy above.
create policy "products_verified_catalogue" on public.products
  for select using (is_verified = true);

drop policy if exists "beta allow all" on public.sales;
create policy "sales_store_all" on public.sales
  for all using (store_id = current_store_id());

drop policy if exists "beta allow all" on public.sale_items;
create policy "sale_items_store_all" on public.sale_items
  for all using (store_id = current_store_id());

drop policy if exists "beta allow all" on public.credit_customers;
create policy "credit_customers_store_all" on public.credit_customers
  for all using (store_id = current_store_id());

drop policy if exists "beta allow all" on public.credit_transactions;
create policy "credit_transactions_store_all" on public.credit_transactions
  for all using (store_id = current_store_id());

drop policy if exists "beta allow all" on public.devices;
create policy "devices_store_all" on public.devices
  for all using (store_id = current_store_id());

drop policy if exists "beta allow all" on public.sync_log;
create policy "sync_log_store_all" on public.sync_log
  for all using (store_id = current_store_id());
