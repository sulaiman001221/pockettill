-- Replaces the single-trusted-device-per-store model (stores.active_device_id)
-- with per-(device, store) verification: a device can be independently
-- trusted by multiple store accounts at once, each verified once via OTP.

alter table public.devices
  add column verified_at timestamptz null;

alter table public.devices
  drop constraint devices_pkey;

alter table public.devices
  add constraint devices_pkey primary key (id, store_id);

alter table public.stores
  drop column active_device_id;
