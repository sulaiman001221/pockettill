create or replace view public.sales_daily_stats
with (security_invoker = true) as
select
  date_trunc('day', created_at)::date as day,
  count(distinct store_id) as active_stores,
  count(*) as sales_count,
  coalesce(sum(total), 0) as revenue
from public.sales
group by date_trunc('day', created_at)::date;

create or replace function public.category_sales_stats(days integer)
returns table(category text, total_quantity bigint)
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(p.category, 'Uncategorized') as category, sum(si.quantity)::bigint as total_quantity
  from public.sale_items si
  join public.sales s on s.uuid = si.sale_uuid
  join public.products p on p.uuid = si.product_uuid
  where s.created_at >= now() - (days || ' days')::interval
  group by coalesce(p.category, 'Uncategorized')
  order by total_quantity desc;
$$;
