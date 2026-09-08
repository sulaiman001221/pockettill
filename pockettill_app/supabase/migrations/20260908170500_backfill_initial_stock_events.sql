-- One-time backfill: bring existing products' current stock quantities
-- into the event-sourcing model without data loss. Every subsequent
-- change (sale/restock/manual/return) layers on top of this as its own
-- delta event.
insert into public.stock_events (store_id, product_id, device_id, change_type, quantity_delta, created_at)
select store_id, uuid, 'migration', 'initial_stock', stock, now()
from public.products
where stock > 0;
