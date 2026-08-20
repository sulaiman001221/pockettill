-- Risk Log: an append-only audit trail of potentially suspicious stock/
-- credit activity (manual stock reductions, product deletions, price
-- changes, manual credit additions, credit write-offs) surfaced on the
-- Risk Log screen for the store owner to review.

create table public.risk_log (
  uuid uuid primary key default gen_random_uuid(),
  type text not null,
  description text not null,
  before_value text,
  after_value text,
  entity_name text not null,
  created_at timestamptz not null default now(),
  store_id uuid references public.stores(uuid)
);

alter table public.risk_log enable row level security;

create policy risk_log_store_all on public.risk_log
  for all
  using (store_id = current_store_id())
  with check (store_id = current_store_id());
