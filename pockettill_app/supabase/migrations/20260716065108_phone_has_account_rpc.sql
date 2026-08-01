-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260716065108). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.
--
-- NOTE: superseded by the two fix migrations that follow
-- (20260716065149, 20260724200321) - kept as an accurate historical record.

-- Lets the client check whether a phone number already has an account
-- before starting registration (or before sending a password-reset OTP),
-- without exposing auth.users to anon/authenticated clients directly.
CREATE OR REPLACE FUNCTION public.phone_has_account(check_phone text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM auth.users WHERE phone = check_phone);
END;
$$;
