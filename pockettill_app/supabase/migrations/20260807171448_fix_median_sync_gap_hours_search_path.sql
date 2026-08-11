create or replace function public.median_sync_gap_hours()
returns numeric
language sql
stable
security invoker
set search_path = ''
as $$
  select percentile_cont(0.5) within group (order by gap_hours)
  from (
    select extract(epoch from (created_at - lag(created_at) over (partition by store_id order by created_at))) / 3600 as gap_hours
    from public.sync_log
  ) gaps
  where gap_hours is not null;
$$;
