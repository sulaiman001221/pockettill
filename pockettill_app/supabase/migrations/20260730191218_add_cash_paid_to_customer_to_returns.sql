-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260730191218). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.

ALTER TABLE public.returns ADD COLUMN IF NOT EXISTS cash_paid_to_customer numeric NOT NULL DEFAULT 0;
