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

`products` has **two** permissive policies (combined with OR): a store
either owns the row, or the row is a verified catalogue entry anyone can
read — this is what lets barcode-scan autofill pull in another store's
verified product data.

## RPC functions

All `SECURITY DEFINER`, all callable by `anon` and `authenticated` (flagged
by Supabase's security advisor as expected/intentional — see below).

- **`current_store_id() returns uuid`** — `select uuid from stores where auth_user_id = auth.uid() limit 1`. The RLS resolver every `*_store_all` policy calls.
- **`is_founding_store() returns boolean`** — `true` while fewer than 100 stores have `is_beta_adopter = true`.
- **`check_founding_store_qualification(store_uuid uuid) returns table(...)`** — idempotent check/promote: a store qualifies once it's ≥7 days old, has ≥5 recorded sales, and founding slots remain; promotes it in the same call if so.
- **`phone_has_account(check_phone text) returns boolean`** — true only when the phone has **both** an `auth.users` row and a matching `stores` row (as of 2026-08-02; previously just checked `auth.users`, which permanently blocked re-registration for a phone whose registration was interrupted before its `stores` row was created). Checks `auth.users.phone` (stored **without** a leading `+`) against `ltrim(check_phone, '+')`, so the app can pass a `+27...`-formatted number directly.

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
