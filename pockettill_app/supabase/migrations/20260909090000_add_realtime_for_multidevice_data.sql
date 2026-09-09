-- Extends Realtime beyond stock_events (added 2026-09-09 for stock sync) to
-- the other core entities a second device needs to see live: sales made
-- elsewhere, returns processed elsewhere, risk log entries logged
-- elsewhere, and products created/edited elsewhere (new products, price
-- changes - not stock, which stays stock_events-driven).
alter publication supabase_realtime add table public.sales;
alter publication supabase_realtime add table public.sale_items;
alter publication supabase_realtime add table public.returns;
alter publication supabase_realtime add table public.return_items;
alter publication supabase_realtime add table public.risk_log;
alter publication supabase_realtime add table public.products;
