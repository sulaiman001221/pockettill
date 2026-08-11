create or replace function public.database_usage_bytes()
returns table(db_size_bytes bigint, storage_size_bytes bigint)
language sql
stable
security definer
set search_path = ''
as $$
  select
    pg_database_size(current_database()) as db_size_bytes,
    (select coalesce(sum((metadata->>'size')::bigint), 0) from storage.objects) as storage_size_bytes;
$$;

revoke execute on function public.database_usage_bytes() from anon, authenticated;
