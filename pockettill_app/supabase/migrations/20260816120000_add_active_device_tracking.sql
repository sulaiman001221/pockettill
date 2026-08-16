-- Tracks which device is currently "active" for a store, so a device that
-- gets signed out (its refresh token revoked because a different device
-- logged in) can tell that apart from a natural session expiry.
alter table public.stores add column if not exists active_device_id text;

-- SECURITY DEFINER + narrow boolean return (mirrors phone_has_account):
-- callable pre-auth (the calling device has just been signed out, so it has
-- no valid JWT), without exposing the raw stores row to anon.
create or replace function public.signed_out_by_new_device(p_store_id uuid, p_device_id text)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_active_device_id text;
begin
  select active_device_id into v_active_device_id
  from stores
  where uuid = p_store_id;

  return v_active_device_id is not null and v_active_device_id <> p_device_id;
end;
$$;

grant execute on function public.signed_out_by_new_device(uuid, text) to anon, authenticated, service_role;
