-- Server-authoritative stock and credit balance.
--
-- Until now every device kept its own running total for products.stock and
-- credit_customers.balance and tried to reconcile with the others through
-- event replays plus client-side conflict rules. That gave each field two
-- sources of truth, which is why devices drifted apart. From here on the
-- database owns both numbers: they only ever change through the ledger
-- tables (stock_events / credit_transactions) via the triggers below, and
-- every device just mirrors the row (plus its own not-yet-sent changes).
--
-- Also adds per-row versioning + two atomic edit functions for the
-- "a person typed a new value in a form" case (the only place a real
-- conflict can exist), and server-assigned received_at cursors so devices
-- can reliably pull anything they missed.

-- ---------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------

alter table public.products
  add column if not exists version integer not null default 0,
  add column if not exists stock_version integer not null default 0;
alter table public.products alter column stock set default 0;
update public.products set updated_at = coalesce(updated_at, created_at) where updated_at is null;
alter table public.products alter column updated_at set default now();

alter table public.credit_customers
  add column if not exists version integer not null default 0,
  add column if not exists updated_at timestamptz;
update public.credit_customers
  set updated_at = coalesce(last_activity_at, created_at)
  where updated_at is null;
alter table public.credit_customers alter column updated_at set default now();
alter table public.credit_customers alter column updated_at set not null;

-- Server-stamped arrival time for every append-only table, so a device's
-- "what did I miss" query never depends on another device's clock.
alter table public.sales add column if not exists received_at timestamptz;
alter table public.sale_items add column if not exists received_at timestamptz;
alter table public.returns add column if not exists received_at timestamptz;
alter table public.return_items add column if not exists received_at timestamptz;
alter table public.extra_income add column if not exists received_at timestamptz;
alter table public.risk_log add column if not exists received_at timestamptz;
alter table public.credit_transactions add column if not exists received_at timestamptz;

update public.sales set received_at = created_at where received_at is null;
update public.returns set received_at = created_at where received_at is null;
update public.extra_income set received_at = created_at where received_at is null;
update public.risk_log set received_at = created_at where received_at is null;
update public.credit_transactions set received_at = created_at where received_at is null;
update public.sale_items si set received_at = s.created_at
  from public.sales s where s.uuid = si.sale_uuid and si.received_at is null;
update public.return_items ri set received_at = r.created_at
  from public.returns r where r.uuid = ri.return_uuid and ri.received_at is null;
update public.sale_items set received_at = now() where received_at is null;
update public.return_items set received_at = now() where received_at is null;

alter table public.sales alter column received_at set default now();
alter table public.sale_items alter column received_at set default now();
alter table public.returns alter column received_at set default now();
alter table public.return_items alter column received_at set default now();
alter table public.extra_income alter column received_at set default now();
alter table public.risk_log alter column received_at set default now();
alter table public.credit_transactions alter column received_at set default now();
alter table public.sales alter column received_at set not null;
alter table public.sale_items alter column received_at set not null;
alter table public.returns alter column received_at set not null;
alter table public.return_items alter column received_at set not null;
alter table public.extra_income alter column received_at set not null;
alter table public.risk_log alter column received_at set not null;
alter table public.credit_transactions alter column received_at set not null;

create index if not exists sales_store_received_idx on public.sales (store_id, received_at);
create index if not exists sale_items_store_received_idx on public.sale_items (store_id, received_at);
create index if not exists returns_store_received_idx on public.returns (store_id, received_at);
create index if not exists return_items_store_received_idx on public.return_items (store_id, received_at);
create index if not exists extra_income_store_received_idx on public.extra_income (store_id, received_at);
create index if not exists risk_log_store_received_idx on public.risk_log (store_id, received_at);
create index if not exists credit_tx_store_received_idx on public.credit_transactions (store_id, received_at);
create index if not exists products_store_updated_idx on public.products (store_id, updated_at);
create index if not exists credit_customers_store_updated_idx on public.credit_customers (store_id, updated_at);

-- ---------------------------------------------------------------------------
-- 2. One-time reconciliation of stock to the ledger
-- ---------------------------------------------------------------------------
-- products.stock lagged every sale (sales only ever wrote stock_events), so
-- the ledger is the accurate number wherever it has any events. Products
-- with no events keep their column value.
update public.products p
  set stock = s.sum_delta, updated_at = now()
  from (
    select product_id, sum(quantity_delta)::integer as sum_delta
    from public.stock_events group by product_id
  ) s
  where s.product_id = p.uuid and p.stock <> s.sum_delta;

-- The owner's last manual stock edit on this product (100 -> 10, visible in
-- risk_log) was applied as an absolute value and never reached the ledger.
update public.products
  set stock = 10, updated_at = now()
  where uuid = (
    select p.uuid from public.products p
    where p.store_id = 'ef9e5276-223c-445b-8c2a-2030a4f83556'
      and p.name = 'Doritos Sour Cream Mild Chilli Flavoured Corn Chips'
      and p.mass = '145g'
    limit 1
  ) and stock = 50;
insert into public.stock_events (id, store_id, product_id, device_id, change_type, quantity_delta, created_at)
select gen_random_uuid(), p.store_id, p.uuid, 'migration', 'manual_adjustment', -40, now()
from public.products p
where p.store_id = 'ef9e5276-223c-445b-8c2a-2030a4f83556'
  and p.name = 'Doritos Sour Cream Mild Chilli Flavoured Corn Chips'
  and p.mass = '145g'
  and p.stock = 10
  and not exists (
    select 1 from public.stock_events e
    where e.product_id = p.uuid and e.device_id = 'migration' and e.change_type = 'manual_adjustment'
  );

-- ---------------------------------------------------------------------------
-- 3. Triggers
-- ---------------------------------------------------------------------------

create or replace function public.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists products_touch_updated_at on public.products;
create trigger products_touch_updated_at
  before update on public.products
  for each row execute function public.touch_updated_at();

drop trigger if exists credit_customers_touch_updated_at on public.credit_customers;
create trigger credit_customers_touch_updated_at
  before update on public.credit_customers
  for each row execute function public.touch_updated_at();

-- Stock and balance are only writable by the ledger triggers below. Any
-- other write (an old app version pushing an absolute value, a stray
-- upsert) is ignored for these two columns instead of overwriting the
-- server's number.
create or replace function public.guard_product_stock()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.stock := 0;
  elsif current_setting('app.stock_write', true) is distinct from '1' then
    new.stock := old.stock;
    new.version := old.version;
    new.stock_version := old.stock_version;
  end if;
  return new;
end;
$$;

-- version/stock_version are only bumped by apply_product_edit, which sets
-- app.stock_write itself, so an ordinary client update can't forge them.
drop trigger if exists products_guard_stock on public.products;
create trigger products_guard_stock
  before insert or update on public.products
  for each row execute function public.guard_product_stock();

create or replace function public.guard_customer_balance()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.balance := 0;
  elsif current_setting('app.balance_write', true) is distinct from '1' then
    new.balance := old.balance;
    new.version := old.version;
  end if;
  return new;
end;
$$;

drop trigger if exists credit_customers_guard_balance on public.credit_customers;
create trigger credit_customers_guard_balance
  before insert or update on public.credit_customers
  for each row execute function public.guard_customer_balance();

create or replace function public.apply_stock_event_to_product()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform set_config('app.stock_write', '1', true);
  update public.products
    set stock = stock + new.quantity_delta
    where uuid = new.product_id and store_id = new.store_id;
  perform set_config('app.stock_write', '0', true);
  return null;
end;
$$;

drop trigger if exists stock_events_apply_delta on public.stock_events;
create trigger stock_events_apply_delta
  after insert on public.stock_events
  for each row execute function public.apply_stock_event_to_product();

create or replace function public.apply_credit_tx_to_customer()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_delta numeric;
begin
  -- purchase / manual_credit raise the balance; repayment / writeoff lower
  -- it; a return already carries its own sign.
  v_delta := case new.type
    when 'repayment' then -new.amount
    when 'writeoff' then -new.amount
    when 'purchase' then new.amount
    when 'manual_credit' then new.amount
    when 'return' then new.amount
    else 0
  end;
  if v_delta = 0 then
    return null;
  end if;
  perform set_config('app.balance_write', '1', true);
  update public.credit_customers
    set balance = greatest(balance + v_delta, 0),
        last_activity_at = greatest(coalesce(last_activity_at, new.created_at), new.created_at)
    where uuid::text = new.customer_id and store_id = new.store_id;
  perform set_config('app.balance_write', '0', true);
  return null;
end;
$$;

drop trigger if exists credit_transactions_apply_delta on public.credit_transactions;
create trigger credit_transactions_apply_delta
  after insert on public.credit_transactions
  for each row execute function public.apply_credit_tx_to_customer();

-- ---------------------------------------------------------------------------
-- 4. Atomic edit functions (a person typed a new value in a form)
-- ---------------------------------------------------------------------------
-- p_base holds the values the editing device saw before its edit, p_changes
-- the new values - only the keys that device actually changed. Per field:
-- already at the new value -> nothing to do (a retry, or two devices making
-- the same change: not a conflict); still at the base value -> apply;
-- anything else -> someone else changed it first: keep the server's value,
-- report the field as conflicting.

create or replace function public.apply_product_edit(
  p_uuid uuid,
  p_store_id uuid,
  p_device_id text,
  p_base jsonb,
  p_changes jsonb,
  p_base_stock_version integer,
  p_stock_delta integer,
  p_edit_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.products%rowtype;
  v_cur jsonb;
  v_key text;
  v_apply jsonb := '{}'::jsonb;
  v_conflicts text[] := '{}';
  v_touched boolean := false;
  v_stock_touched boolean := false;
begin
  select * into v_row from public.products
    where uuid = p_uuid and store_id = p_store_id for update;
  if not found then
    return jsonb_build_object('found', false, 'conflicts', '[]'::jsonb, 'row', null);
  end if;
  v_cur := to_jsonb(v_row);

  for v_key in select jsonb_object_keys(coalesce(p_changes, '{}'::jsonb)) loop
    if (v_cur -> v_key) is not distinct from (p_changes -> v_key) then
      continue;
    elsif (v_cur -> v_key) is not distinct from (p_base -> v_key) then
      v_apply := v_apply || jsonb_build_object(v_key, p_changes -> v_key);
    else
      v_conflicts := array_append(v_conflicts, v_key);
    end if;
  end loop;

  if v_apply <> '{}'::jsonb then
    perform set_config('app.stock_write', '1', true);
    update public.products set
      name = case when v_apply ? 'name' then v_apply ->> 'name' else name end,
      barcode = case when v_apply ? 'barcode' then v_apply ->> 'barcode' else barcode end,
      mass = case when v_apply ? 'mass' then v_apply ->> 'mass' else mass end,
      category = case when v_apply ? 'category' then v_apply ->> 'category' else category end,
      unit = case when v_apply ? 'unit' then v_apply ->> 'unit' else unit end,
      price = case when v_apply ? 'price' then (v_apply ->> 'price')::numeric else price end,
      cost_price = case when v_apply ? 'cost_price' then (v_apply ->> 'cost_price')::numeric else cost_price end,
      low_stock_threshold = case when v_apply ? 'low_stock_threshold' then (v_apply ->> 'low_stock_threshold')::integer else low_stock_threshold end,
      version = version + 1
    where uuid = p_uuid;
    perform set_config('app.stock_write', '0', true);
    v_touched := true;
  end if;

  if coalesce(p_stock_delta, 0) <> 0 then
    if exists (select 1 from public.stock_events where id = p_edit_id) then
      null; -- this exact edit already landed (a retry)
    elsif v_row.stock_version is distinct from p_base_stock_version then
      v_conflicts := array_append(v_conflicts, 'stock');
    else
      insert into public.stock_events
        (id, store_id, product_id, device_id, change_type, quantity_delta, created_at)
      values
        (p_edit_id, p_store_id, p_uuid, p_device_id, 'manual_adjustment', p_stock_delta, now());
      v_stock_touched := true;
    end if;
  end if;

  if v_stock_touched then
    perform set_config('app.stock_write', '1', true);
    update public.products
      set stock_version = stock_version + 1,
          version = version + case when v_touched then 0 else 1 end
      where uuid = p_uuid;
    perform set_config('app.stock_write', '0', true);
  end if;

  return jsonb_build_object(
    'found', true,
    'conflicts', to_jsonb(v_conflicts),
    'row', (select to_jsonb(p) from public.products p where p.uuid = p_uuid)
  );
end;
$$;

revoke all on function public.apply_product_edit(uuid, uuid, text, jsonb, jsonb, integer, integer, uuid) from public;
grant execute on function public.apply_product_edit(uuid, uuid, text, jsonb, jsonb, integer, integer, uuid) to authenticated;

create or replace function public.apply_credit_customer_edit(
  p_uuid uuid,
  p_store_id uuid,
  p_base jsonb,
  p_changes jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.credit_customers%rowtype;
  v_cur jsonb;
  v_key text;
  v_apply jsonb := '{}'::jsonb;
  v_conflicts text[] := '{}';
begin
  select * into v_row from public.credit_customers
    where uuid = p_uuid and store_id = p_store_id for update;
  if not found then
    return jsonb_build_object('found', false, 'conflicts', '[]'::jsonb, 'row', null);
  end if;
  v_cur := to_jsonb(v_row);

  for v_key in select jsonb_object_keys(coalesce(p_changes, '{}'::jsonb)) loop
    if (v_cur -> v_key) is not distinct from (p_changes -> v_key) then
      continue;
    elsif (v_cur -> v_key) is not distinct from (p_base -> v_key) then
      v_apply := v_apply || jsonb_build_object(v_key, p_changes -> v_key);
    else
      v_conflicts := array_append(v_conflicts, v_key);
    end if;
  end loop;

  if v_apply <> '{}'::jsonb then
    perform set_config('app.balance_write', '1', true);
    update public.credit_customers set
      name = case when v_apply ? 'name' then v_apply ->> 'name' else name end,
      phone = case when v_apply ? 'phone' then v_apply ->> 'phone' else phone end,
      credit_limit = case when v_apply ? 'credit_limit' then (v_apply ->> 'credit_limit')::numeric else credit_limit end,
      version = version + 1
    where uuid = p_uuid;
    perform set_config('app.balance_write', '0', true);
  end if;

  return jsonb_build_object(
    'found', true,
    'conflicts', to_jsonb(v_conflicts),
    'row', (select to_jsonb(c) from public.credit_customers c where c.uuid = p_uuid)
  );
end;
$$;

revoke all on function public.apply_credit_customer_edit(uuid, uuid, jsonb, jsonb) from public;
grant execute on function public.apply_credit_customer_edit(uuid, uuid, jsonb, jsonb) to authenticated;

-- The two earlier row-level compare-and-swap functions are superseded.
drop function if exists public.apply_product_edit(uuid, uuid, text, numeric, text, text, integer, text, numeric, text, text, integer);
drop function if exists public.apply_credit_customer_edit(uuid, uuid, text, text, numeric, numeric, text, text, numeric, numeric);
