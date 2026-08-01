-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260716065149). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.
--
-- NOTE: superseded by 20260724200321 (adds `SET search_path`) - kept as an
-- accurate historical record.

-- auth.users.phone is stored without the leading '+' (E.164 digits only),
-- but the app always passes a '+27...'-formatted number - normalize before
-- comparing so this actually matches.
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
