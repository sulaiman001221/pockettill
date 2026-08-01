-- Pulled verbatim from supabase_migrations.schema_migrations (version
-- 20260714192203). Reflects exactly what is tracked as applied on the live
-- project - do not edit historical migrations, only add new ones.
--
-- NOTE: the "beta allow all" policies this touches were later dropped and
-- replaced with real per-store policies - see
-- 20260718000000_reconstructed_rls_hardening.sql. This file is kept as an
-- accurate historical record of what was actually run.

-- Stage 12's "beta allow all" policies only covered the anon role, back
-- when every request used the shared anon key. Stage 13 adds real Supabase
-- Auth sessions, which switch to the authenticated role - extend the same
-- temporary allow-all policies to cover it too, so logged-in devices can
-- actually sync.
ALTER POLICY "beta allow all" ON public.products TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.sales TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.sale_items TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.credit_customers TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.credit_transactions TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.devices TO anon, authenticated;
ALTER POLICY "beta allow all" ON public.sync_log TO anon, authenticated;
