-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260724200321). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.
--
-- Current live definition of public.phone_has_account() as of this
-- migration - adds `SET search_path TO 'public'` (defensive, prevents a
-- search_path hijack against this SECURITY DEFINER function).

CREATE OR REPLACE FUNCTION public.phone_has_account(check_phone text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE phone = ltrim(check_phone, '+')
  );
END;
$function$;
