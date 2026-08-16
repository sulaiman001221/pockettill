-- One-off income that isn't a regular sale (airtime, electricity tokens,
-- etc.) - counted toward Sales History/End of Day totals but never treated
-- as a sale.

create table public.extra_income (
  uuid uuid primary key default gen_random_uuid(),
  amount numeric not null,
  description text not null,
  created_at timestamptz not null default now(),
  store_id uuid references public.stores(uuid)
);

alter table public.extra_income enable row level security;

create policy extra_income_store_all on public.extra_income
  for all
  using (store_id = current_store_id())
  with check (store_id = current_store_id());
