-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260714172513). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.

CREATE TABLE IF NOT EXISTS public.stores (
  uuid uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_name text,
  owner_phone text NOT NULL,
  address text,
  is_beta_adopter boolean NOT NULL DEFAULT false,
  beta_joined_at timestamptz,
  discount_rate numeric NOT NULL DEFAULT 1.0,
  auth_user_id uuid REFERENCES auth.users(id) UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  active boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS stores_auth_user_id_idx
  ON public.stores (auth_user_id);

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(uuid);

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(uuid);

ALTER TABLE public.sale_items
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(uuid);

ALTER TABLE public.credit_customers
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(uuid);

ALTER TABLE public.credit_transactions
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(uuid);

ALTER TABLE public.devices
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(uuid);

ALTER TABLE public.sync_log
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(uuid);

CREATE OR REPLACE FUNCTION public.is_founding_store()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM public.stores) < 100;
END;
$$;
