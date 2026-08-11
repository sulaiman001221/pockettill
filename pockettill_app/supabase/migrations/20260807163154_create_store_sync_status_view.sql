create or replace view public.store_sync_status
with (security_invoker = true) as
select store_id, max(created_at) as last_synced_at
from public.sync_log
group by store_id;
