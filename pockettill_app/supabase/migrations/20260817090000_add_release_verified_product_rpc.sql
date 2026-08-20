-- A store "deleting" one of its own products must never destroy shared
-- crowdsourced catalogue data: once a product is approved (is_verified =
-- true), other stores' barcode lookups depend on that exact row regardless
-- of which store originally submitted it. Previously the app issued a plain
-- DELETE for any product the owning store removed, which - for a verified
-- row - deleted the catalogue entry out from under every other store.
--
-- This detaches the row from the deleting store (store_id = null) instead
-- of deleting it, so the verified data survives for cross-store barcode
-- lookups (RLS's products_verified_catalogue SELECT policy has no store_id
-- restriction) while it correctly disappears from the deleting store's own
-- inventory (products_store_all requires store_id = current_store_id()).
--
-- SECURITY DEFINER so the store_id column can be nulled at all - the
-- existing products_store_all policy's WITH CHECK (implicitly mirroring its
-- USING clause, store_id = current_store_id()) would otherwise reject an
-- UPDATE that sets store_id to something other than the caller's own store.
-- Scoped tightly: only touches a row the caller's store currently owns, and
-- only when it's actually verified - a non-verified product should still
-- go through a normal delete, since that's genuinely private, unshared data.
create or replace function public.release_verified_product(p_uuid uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  update products
  set store_id = null
  where uuid = p_uuid
    and store_id = current_store_id()
    and is_verified = true;
end;
$$;

grant execute on function public.release_verified_product(uuid) to authenticated;
