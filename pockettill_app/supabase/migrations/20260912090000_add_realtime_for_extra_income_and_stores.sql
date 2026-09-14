-- More gaps found in two-device testing (2026-09-12): extra_income, store
-- profile edits (stores), and the entire credit-customers section
-- (credit_customers, credit_transactions) never reached a second device at
-- all - none of these four tables were ever added to supabase_realtime.
alter publication supabase_realtime add table public.extra_income;
alter publication supabase_realtime add table public.stores;
alter publication supabase_realtime add table public.credit_customers;
alter publication supabase_realtime add table public.credit_transactions;
