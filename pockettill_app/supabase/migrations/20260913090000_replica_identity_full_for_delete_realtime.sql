-- Supabase Realtime needs a DELETE's full old row (not just the primary
-- key, the default) to evaluate a table's RLS policy against a subscriber
-- - credit_customers_store_all/products_store_all both key off store_id,
-- which a default-REPLICA-IDENTITY delete payload never carries. Without
-- this, a delete on either table was never delivered to any RLS-scoped
-- client at all, regardless of how correct the app's own subscription code
-- was - found 2026-09-13 diagnosing why customer/product deletes never
-- synced live to a second device.
alter table public.credit_customers replica identity full;
alter table public.products replica identity full;
