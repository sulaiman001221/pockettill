-- Category counts for the Flutter app's Catalogue Browse screen
-- ("Beverages (124)"). security invoker, no elevated privilege needed -
-- catalogue_products is already readable by any authenticated store via
-- its own RLS policy, this just aggregates over what the caller can see.
create or replace function public.catalogue_category_counts()
returns table(category text, product_count bigint)
language sql
security invoker
set search_path = ''
as $$
  select coalesce(category, 'Uncategorised') as category, count(*) as product_count
  from public.catalogue_products
  group by coalesce(category, 'Uncategorised')
  order by category;
$$;
