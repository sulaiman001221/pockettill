create or replace view public.sync_daily_active_stores
with (security_invoker = true) as
select date_trunc('day', created_at)::date as day, count(distinct store_id) as active_stores
from public.sync_log
group by date_trunc('day', created_at)::date;

create or replace function public.median_sync_gap_hours()
returns numeric
language sql
stable
security invoker
as $$
  select percentile_cont(0.5) within group (order by gap_hours)
  from (
    select extract(epoch from (created_at - lag(created_at) over (partition by store_id order by created_at))) / 3600 as gap_hours
    from public.sync_log
  ) gaps
  where gap_hours is not null;
$$;
