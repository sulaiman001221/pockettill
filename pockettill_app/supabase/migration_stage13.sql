-- ================================================
-- PocketTill Stage 13 Migration
-- Run in Supabase Dashboard -> SQL Editor
-- Run AFTER existing schema is in place
-- ================================================

-- 1. Create stores table
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

-- 2. Add store_id to every existing table
--    Nullable so existing rows are not affected
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

-- 3. Founding store helper function
--    Returns true if fewer than 100 stores exist
CREATE OR REPLACE FUNCTION public.is_founding_store()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM public.stores) < 100;
END;
$$;

-- NOTE: RLS stays OFF for the new `stores` table for now - same as the
-- rest of the beta setup. Will be enabled post-beta when moving to
-- production scale. store_id columns are in place and populated from now
-- on, ready for RLS to be switched on with one ALTER TABLE command.

-- 4. Extend Stage 12's "beta allow all" policies to the authenticated role.
--    Those policies only covered anon, back when every request used the
--    shared anon key. Once a device is actually logged in via Supabase
--    Auth, its requests carry the authenticated role instead - without
--    this, every sync from a logged-in device gets rejected by RLS
--    (42501, e.g. "new row violates row-level security policy for table
--    devices").
ALTER POLICY "beta allow all" ON public.products TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.sales TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.sale_items TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.credit_customers TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.credit_transactions TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.devices TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.sync_log TO anon, authenticated;

-- 5. Lets the client check whether a phone already has an account before
--    starting registration (block duplicate sign-ups) or before sending a
--    password-reset OTP (block resets for numbers with no account), without
--    exposing auth.users to anon/authenticated clients directly.
--    auth.users.phone is stored WITHOUT a leading '+' (E.164 digits only),
--    but the app always passes a '+27...'-formatted number - ltrim strips
--    that so the comparison actually matches.
CREATE OR REPLACE FUNCTION public.phone_has_account(check_phone text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users WHERE phone = ltrim(check_phone, '+')
  );
END;
$$;

-- ================================================
-- END OF MIGRATION
-- ================================================
