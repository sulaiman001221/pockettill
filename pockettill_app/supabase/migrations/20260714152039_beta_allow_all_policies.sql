-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260714152039). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.

-- Temporary allow-all policies for the shared app (anon) key.
-- The app has no per-store authentication yet - swap these for real
-- per-store policies once it does.

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
