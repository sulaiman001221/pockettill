-- The catalogue-split migration (20260817120000) recreated
-- pending_catalogue_items and verified_catalogue_items without their
-- `security_invoker = true` option, silently reverting them to the default
-- SECURITY DEFINER behavior (they'd run as the view owner instead of the
-- querying role) - caught by Supabase's security advisor as an ERROR-level
-- finding during a post-launch sanity check. Restores the property both
-- views had before the split.

alter view public.pending_catalogue_items set (security_invoker = true);
alter view public.verified_catalogue_items set (security_invoker = true);
