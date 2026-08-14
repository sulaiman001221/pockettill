# PocketTill Supabase schema — live state

Project `jaiaolofdxtsbbsyjvio` (pockettill_app, eu-west-1). This document
describes what is **actually running** on that project, verified directly
against it (not against any local file) on **2026-07-31**. If this document
and the migrations in `pockettill_app/supabase/migrations/` ever disagree
with the live project again, trust the live project and re-run this audit —
don't trust either set of files blindly.

The migrations under `pockettill_app/supabase/migrations/` are the source
of truth for *how* this state was reached and should be replayed in order
against a fresh project. This file is a snapshot of the *end result*, for
quickly checking "does X exist / is Y locked down" without reading ten
migration files.

## Tables

All tables live in `public`. Every table has RLS **enabled**.

### `stores`
Owning-account row per store. One row per Supabase Auth user (via
`auth_user_id`).

| column | type | notes |
|---|---|---|
| uuid | uuid PK | `gen_random_uuid()` |
| name | text | |
| owner_name | text | nullable |
| owner_phone | text | |
| address | text | nullable |
| is_beta_adopter | boolean | founding-store flag, earned not signup-order |
| beta_joined_at | timestamptz | nullable |
| discount_rate | numeric | default 1.0 |
| auth_user_id | uuid | FK `auth.users(id)`, UNIQUE |
| created_at | timestamptz | |
| active | boolean | default true |
| otp_channel | text | default `'whatsapp'` — which channel a new-device login challenges the owner on |
| qualification_checked_at | timestamptz | nullable |
| qualification_sales_count | integer | nullable |

### `products`
Shared cross-store catalogue **and** per-store stock/pricing in one table
(no separate `store_products` table — that design was drafted once, in the
now-deleted root `schema.sql`, but never built).

| column | type | notes |
|---|---|---|
| uuid | uuid PK | |
| barcode | text | |
| name | text | |
| mass | text | nullable |
| category | text | nullable |
| unit | text | nullable |
| price | numeric | |
| cost_price | numeric | nullable |
| stock | integer | |
| low_stock_threshold | integer | default 5 |
| is_verified | boolean | default false — gates cross-store catalogue visibility |
| created_at | timestamptz | |
| updated_at | timestamptz | nullable |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |
| verified_at | timestamptz | nullable — added 2026-08-09; set when a product is approved via pockettill_datamaster, null for anything verified before that column existed |

### `sales`
| column | type | notes |
|---|---|---|
| uuid | uuid PK | |
| device_id | text | |
| total | numeric | |
| payment_type | text | `cash` \| `card` \| `credit` |
| customer_id | text | nullable |
| created_at | timestamptz | |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |

### `sale_items`
| column | type | notes |
|---|---|---|
| sale_uuid | uuid | part of composite PK |
| product_uuid | uuid | part of composite PK |
| product_name | text | |
| unit_price | numeric | |
| quantity | integer | |
| subtotal | numeric | |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |

PK: `(sale_uuid, product_uuid)`.

### `credit_customers`
| column | type | notes |
|---|---|---|
| uuid | uuid PK | |
| name | text | |
| phone | text | nullable |
| balance | numeric | default 0 — running total owed by the customer |
| credit_limit | numeric | nullable |
| created_at | timestamptz | |
| last_activity_at | timestamptz | nullable |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |

### `credit_transactions`
| column | type | notes |
|---|---|---|
| uuid | uuid PK | |
| customer_id | text | |
| amount | numeric | |
| type | text | `purchase` \| `repayment` \| `return` |
| sale_uuid | uuid | nullable |
| note | text | nullable — repayment method (`Cash`/`Card`) or return reason label |
| balance_before | numeric | nullable |
| balance_after | numeric | nullable |
| created_at | timestamptz | |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |

### `devices`
Tracks per-(device, store) verification, not a single trusted device per
store — the same physical `id` can have one row per store account it's ever
logged into, each verified independently (as of 2026-08-05; previously
`id` alone was the PK, and `stores.active_device_id` tracked one trusted
device per store — replaced because it couldn't represent one device
holding trust for more than one store account at a time).

| column | type | notes |
|---|---|---|
| id | text | part of composite PK — stable per physical device install, not per store |
| store_id | uuid | FK `stores(uuid)`, part of composite PK |
| verified_at | timestamptz | nullable — null means this (device, store) pairing has never passed the new-device OTP challenge; set once, on first successful verification, and never cleared |
| last_seen_at | timestamptz | nullable |

PK: `(id, store_id)`.

### `sync_log`
| column | type | notes |
|---|---|---|
| id | bigint PK | identity |
| device_id | text | |
| events_pushed | integer | |
| events_pulled | integer | |
| created_at | timestamptz | |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |

### `returns`
| column | type | notes |
|---|---|---|
| uuid | uuid PK | |
| sale_uuid | uuid | |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |
| device_id | text | |
| reason | text | `expired_broken` \| `wrong_item` \| `change_of_mind` |
| stock_action | text | `write_off` \| `restock` |
| resolution_type | text | `refund` \| `exchange` \| `store_credit` |
| items_value | numeric | default 0 |
| customer_owes | numeric | default 0 — gross, cash or balance combined |
| customer_receives | numeric | default 0 — gross, cash or balance combined |
| customer_id | text | nullable |
| exchange_product_uuid | uuid | nullable |
| exchange_product_name | text | nullable |
| created_at | timestamptz | |
| cash_paid_to_customer | numeric | default 0 — added 2026-07-30; the portion of `customer_receives` actually paid as physical cash rather than absorbed into a credit balance |

### `return_items`
| column | type | notes |
|---|---|---|
| uuid | uuid PK | |
| return_uuid | uuid | |
| sale_uuid | uuid | |
| store_id | uuid | FK `stores(uuid)`, nullable, **populated on every row** |
| product_uuid | uuid | nullable |
| product_name | text | |
| unit_price | numeric | |
| quantity | integer | |

### `admin_users`
Backs the **pockettill_datamaster** admin dashboard, not the Flutter app. A
separate identity pool from `stores` — a row here means a `auth.users` account
is allowed to sign into the admin dashboard, scoped by `role`. Added
2026-08-07.

| column | type | notes |
|---|---|---|
| id | uuid PK | FK `auth.users(id)`, `on delete cascade` |
| email | text | |
| full_name | text | nullable |
| role | text | `owner` \| `editor` \| `viewer` |
| is_active | boolean | default true — login is rejected when false |
| created_at | timestamptz | default `now()` |
| invited_by | uuid | nullable, FK `admin_users(id)` **`on delete set null`** (changed 2026-08-11 — was the default `NO ACTION`, which blocked deleting any admin who had invited someone else; now the invitee's `invited_by` just goes null) — null for the first Owner (nobody invited them), set for everyone invited through the Admin Accounts page |
| can_manage_access | boolean | default false — added 2026-08-11. Gates invite/remove/role-change actions in Admin Accounts (`requireAccessManager()` in `src/lib/actions/admin-accounts.ts`), separately from `role`. Owners get this automatically (enforced in app code whenever a row's role is set to `owner` — invite, role change) and it's backfilled true for existing owners by the migration; Editors/Viewers start false and can only be granted it by an Owner toggling it explicitly. Granting/revoking the flag itself is Owner-only (`requireOwner()`), even though the flag it controls extends beyond Owners. |

**Removing an admin** (`removeAdmin` action, 2026-08-11) calls `supabase.auth.admin.deleteUser(id)` on the service-role client — this deletes the `auth.users` row, which cascades to `admin_users` via its own `on delete cascade` FK. Distinct from deactivating (`is_active = false`, reversible): removal is permanent, there's no restore.

### `audit_log`
Backs the pockettill_datamaster Admin Accounts audit trail. Added
2026-08-10. RLS enabled with **zero policies** (deny-all for `anon`/
`authenticated`, intentional — only the dashboard's service-role client
ever reads or writes this). Logging starts from 2026-08-10; nothing before
that was backfilled.

| column | type | notes |
|---|---|---|
| id | uuid PK | `gen_random_uuid()` |
| admin_id | uuid | FK `admin_users(id)`, nullable — who performed the action |
| action | text | dot-namespaced, e.g. `store.deactivated`, `admin.role_changed` |
| target | text | human-readable identifier (store name, barcode, invited email) — chosen so the log is readable without a join |
| metadata | jsonb | default `{}` — extra context (e.g. `{from: "editor", to: "owner"}` for a role change) |
| created_at | timestamptz | default `now()` |

Logged actions: `admin.invited`, `admin.role_changed`, `admin.deactivated`/
`admin.reactivated`, `store.deactivated`/`store.reactivated`,
`store.founding_toggled`, `product.approved`, `product.rejected`,
`support.status_changed`, `support.notes_updated`. Product
edit/unverify (Verified Catalogue's Edit/Remove) are **not** logged — only
the actions explicitly requested were wired up.

### `support_queries`
Contact-form enquiries from the **pockettill_landing** marketing site, shown
in pockettill_datamaster's Support section. Added 2026-08-14. RLS enabled
with **zero policies** (same deny-all posture as `audit_log`) — the only
writer is the landing site's `/api/contact` route and the only reader is the
dashboard, both via service-role. There is deliberately no `anon` insert
policy, so the table is not a public write target.

| column | type | notes |
|---|---|---|
| id | uuid PK | `gen_random_uuid()` |
| name | text | submitter's name |
| contact | text | email **or** SA phone, validated in `pockettill_landing/src/lib/validate.ts` (shared by the browser and the API route) |
| message | text | capped at 4000 chars by the API route |
| status | text | `new` \| `in_progress` \| `resolved`, CHECK-constrained, default `new` |
| source | text | default `landing` — room for future intake channels |
| internal_notes | text | nullable, admin-only, never shown to the submitter |
| handled_by | uuid | nullable, FK `admin_users(id)` `on delete set null` — stamped when status leaves `new`, cleared if pushed back to `new` |
| handled_at | timestamptz | nullable, set/cleared alongside `handled_by` |
| created_at | timestamptz | default `now()` |

Indexed on `created_at desc`, `(status, created_at desc)`, and `handled_by`.
Viewers can read enquiries but not change status or notes
(`canManageStores()` gate in `src/lib/actions/support.ts`).

## Naming gotchas for pockettill_datamaster

The dashboard's own spec writing has twice assumed column names that read
naturally but don't exist. Check here before writing a new query rather than
guessing:

| assumed (wrong) | actual column | table |
|---|---|---|
| `is_active` | `active` | `stores` |
| `is_founding_store` | `is_beta_adopter` | `stores` |
| `synced_at` | `created_at` | `sync_log` |
| `total_amount` | `total` | `sales` |
| `payment_method` | `payment_type` | `sales` |

`is_founding_store` **is** a real identifier, but it's a Postgres function
(see RPC functions below), not a column — `select is_founding_store()`
returns whether founding slots are still open, it does not read a per-store
flag.

`sale_items` has **no foreign key** to `sales` or `products` (only to
`stores`, for RLS) — `sale_uuid`/`product_uuid` are plain columns, part of
the composite PK. PostgREST embedding (`.select('*, products(category)')`)
will not work across them; joins spanning `sale_items` need a raw SQL
view/function, e.g. `category_sales_stats()` below.

## Views

### `store_sync_status`
`security_invoker = true` — respects the querying role's RLS, not the
view owner's. Added 2026-08-07 for pockettill_datamaster (avoids scanning
all of `sync_log` just to find each store's most recent sync).

```sql
select store_id, max(created_at) as last_synced_at
from public.sync_log
group by store_id;
```

A store's `last_synced_at >= now() - interval '24 hours'` is equivalent to
"this store has synced at least once in the last 24h" — same underlying
condition, so this view backs both "last sync" display and "% synced in
last 24h" counts.

### `sync_daily_active_stores`
`security_invoker = true`. Added 2026-08-07 for pockettill_datamaster's
Sync Health trend chart — one row per calendar day with how many distinct
stores synced that day.

```sql
select date_trunc('day', created_at)::date as day, count(distinct store_id) as active_stores
from public.sync_log
group by date_trunc('day', created_at)::date;
```

The dashboard divides `active_stores` by the **current** total store count
for every day in the range (not each day's historical total) — an accepted
simplification while the store count is small and near-static; revisit if
that stops being true.

### `pending_catalogue_items`
`security_invoker = true`. Added 2026-08-09 for pockettill_datamaster's
Verification Queue — one row per barcode across all stores' unverified
submissions, deduplicated. Uses `mode() within group` (most-frequent-value)
so the approve panel can pre-fill with the most common submission, not just
an arbitrary or alphabetically-first one.

```sql
select
  barcode,
  array_agg(distinct name) as name_variations,
  array_agg(distinct category) as category_variations,
  count(distinct store_id) as store_count,
  min(created_at) as first_submitted,
  mode() within group (order by name) as most_common_name,
  mode() within group (order by category) as most_common_category,
  mode() within group (order by mass) as most_common_mass
from public.products
where is_verified = false
group by barcode;
```

### `verified_catalogue_items`
`security_invoker = true`. Added 2026-08-09, same shape idea as above but
for `is_verified = true` rows — one row per barcode. `name`/`category` are
forced uniform across every row sharing a barcode by the approve action (a
single `UPDATE ... WHERE barcode = X`), so `mode()` on them is really just
reading that shared value back; `mass` genuinely can still vary per store
(different pack sizes), so `mode()` there picks the most common one for
display purposes only — it is not written back anywhere.

```sql
select
  barcode,
  mode() within group (order by name) as name,
  mode() within group (order by category) as category,
  mode() within group (order by mass) as mass,
  max(verified_at) as verified_at,
  count(distinct store_id) as store_count
from public.products
where is_verified = true
group by barcode;
```

### `sales_daily_stats`
`security_invoker = true`. Added 2026-08-09 for pockettill_datamaster's
Analytics page — one row per calendar day across all stores. Backs the
Daily Active Stores and Sales Volume Trend charts, and the period summary
stats (total sales/revenue are just `sum()` over the selected day range,
computed app-side from these rows rather than a second query).

```sql
select
  date_trunc('day', created_at)::date as day,
  count(distinct store_id) as active_stores,
  count(*) as sales_count,
  coalesce(sum(total), 0) as revenue
from public.sales
group by date_trunc('day', created_at)::date;
```

## Row Level Security

Every `store_id`-bearing table follows the same pattern: one `for all`
policy gated on `store_id = current_store_id()`. There is **no** `anon`-only
or "allow all" policy left anywhere — that Stage 12 scaffolding was fully
replaced.

| table | policy | command | using |
|---|---|---|---|
| stores | `stores_select` | SELECT | `auth_user_id = auth.uid()` |
| stores | `stores_insert` | INSERT | check: `auth_user_id = auth.uid()` |
| stores | `stores_update` | UPDATE | `auth_user_id = auth.uid()` |
| products | `products_store_all` | ALL | `store_id = current_store_id()` |
| products | `products_verified_catalogue` | SELECT | `is_verified = true` |
| sales | `sales_store_all` | ALL | `store_id = current_store_id()` |
| sale_items | `sale_items_store_all` | ALL | `store_id = current_store_id()` |
| credit_customers | `credit_customers_store_all` | ALL | `store_id = current_store_id()` |
| credit_transactions | `credit_transactions_store_all` | ALL | `store_id = current_store_id()` |
| devices | `devices_store_all` | ALL | `store_id = current_store_id()` |
| sync_log | `sync_log_store_all` | ALL | `store_id = current_store_id()` |
| returns | `returns_store_all` | ALL | `store_id = current_store_id()` |
| return_items | `return_items_store_all` | ALL | `store_id = current_store_id()` |
| admin_users | `admin_users_select_own` | SELECT | `id = auth.uid()` |
| audit_log | *(none — deny all)* | — | service-role only |
| support_queries | *(none — deny all)* | — | service-role only |

`products` has **two** permissive policies (combined with OR): a store
either owns the row, or the row is a verified catalogue entry anyone can
read — this is what lets barcode-scan autofill pull in another store's
verified product data.

## RPC functions

The original four (`current_store_id` through `phone_has_account`) are all
`SECURITY DEFINER` and callable by `anon`/`authenticated` (flagged by
Supabase's security advisor as expected/intentional — see below). The two
added later for pockettill_datamaster are `SECURITY INVOKER` instead —
they don't need elevated privilege, so they run under the caller's own RLS.

- **`current_store_id() returns uuid`** — `select uuid from stores where auth_user_id = auth.uid() limit 1`. The RLS resolver every `*_store_all` policy calls.
- **`is_founding_store() returns boolean`** — `true` while fewer than 100 stores have `is_beta_adopter = true`.
- **`check_founding_store_qualification(store_uuid uuid) returns table(...)`** — idempotent check/promote: a store qualifies once it's ≥7 days old, has ≥5 recorded sales, and founding slots remain; promotes it in the same call if so.
- **`phone_has_account(check_phone text) returns boolean`** — true only when the phone has **both** an `auth.users` row and a matching `stores` row (as of 2026-08-02; previously just checked `auth.users`, which permanently blocked re-registration for a phone whose registration was interrupted before its `stores` row was created). Checks `auth.users.phone` (stored **without** a leading `+`) against `ltrim(check_phone, '+')`, so the app can pass a `+27...`-formatted number directly.
- **`median_sync_gap_hours() returns numeric`** — `security invoker`, `set search_path = ''`. Added 2026-08-07 for pockettill_datamaster's Sync Health summary stat. Platform-wide median of the gaps (in hours) between consecutive `sync_log` rows for the same store (`lag()` partitioned by `store_id`). Runs under the caller's RLS, so calling it as `anon`/`authenticated` only aggregates over rows that role can see — the dashboard calls it via the service-role client to get the true platform-wide figure.
- **`category_sales_stats(days integer) returns table(category text, total_quantity bigint)`** — `security invoker`, `set search_path = ''`. Added 2026-08-09 for pockettill_datamaster's Analytics page. Joins `sale_items` → `sales` (for the date bound) → `products` (for category) in raw SQL, sidestepping the missing FK on `sale_items` noted above. `days` is how far back from `now()` to include.
- **`database_usage_bytes() returns table(db_size_bytes bigint, storage_size_bytes bigint)`** — `security definer`, `set search_path = ''`, **execute revoked from `public`/`anon`/`authenticated`** (only the service-role client can call it — this one actually needs to be locked down, unlike the others in this list, since it exposes infra sizing that shouldn't be publicly queryable). Added 2026-08-10 for pockettill_datamaster's Infrastructure Costs page, after discovering Supabase's public Management API has **no endpoint for database/storage size** despite what the page's original spec assumed (`GET /v1/projects/{ref}/usage` doesn't exist — confirmed 404 against the real API; the only real usage endpoints are `analytics/endpoints/usage.api-counts` and `usage.api-requests-count`). `pg_database_size(current_database())` and a `sum` over `storage.objects.metadata->>'size'` are the actual, reliable sources. Note when creating any new `security definer` function: **Postgres grants `EXECUTE` to `PUBLIC` by default** — `revoke ... from anon, authenticated` alone does not remove a standing `PUBLIC` grant; revoke from `public` explicitly too, or the security advisor will still flag it (this bit us once already, see `20260810141855_fix_database_usage_bytes_grants.sql`).

## Known advisor warnings (accepted, not bugs)

- The four RPCs above are flagged as "Public Can Execute SECURITY DEFINER
  Function" for both `anon` and `authenticated` — intentional, they're
  meant to be called pre-login (`phone_has_account`) or don't leak anything
  sensitive (`current_store_id`, `is_founding_store`,
  `check_founding_store_qualification`).
- Leaked password protection is disabled in Auth settings — unrelated to
  schema/RLS, not addressed by this audit.

## Provenance gotcha

`pockettill_app/supabase/migrations/20260718000000_reconstructed_rls_hardening.sql`
reconstructs the swap from Stage 12's "beta allow all" policies to the real
per-store policies above, plus `current_store_id()` and the `stores` RLS
policies. That work was applied directly against the live project in an
earlier session and has **no corresponding entry** in Supabase's own
`supabase_migrations.schema_migrations` table — every other migration in
that folder does. Do not re-run it against `jaiaolofdxtsbbsyjvio`; it's
there so a fresh project could be bootstrapped to the same state, and so
the gap is documented rather than silently missing.
