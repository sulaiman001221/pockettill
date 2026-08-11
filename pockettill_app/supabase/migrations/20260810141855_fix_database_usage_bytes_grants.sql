-- create's implicit PUBLIC grant survived the anon/authenticated-only revoke
-- in the previous migration; anon/authenticated inherit from PUBLIC.
revoke execute on function public.database_usage_bytes() from public;
revoke execute on function public.database_usage_bytes() from anon, authenticated;
