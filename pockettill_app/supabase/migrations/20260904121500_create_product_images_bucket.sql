-- Public-read bucket: product photos aren't sensitive, and the shared
-- catalogue browse feature needs every store's images viewable by every
-- other store, not just the uploading one. Writes are still locked down
-- below to each store's own path prefix.
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- Path convention: {store_id}/{product_id}.jpg - storage.foldername(name)
-- splits "abc/def.jpg" into ['abc', 'def.jpg'], so element 1 is the store_id
-- segment. Mirrors the current_store_id() pattern used by every other
-- store_id-scoped table's RLS policy.
create policy "product_images_public_read"
on storage.objects for select
to public
using (bucket_id = 'product-images');

create policy "product_images_store_insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = current_store_id()::text
);

create policy "product_images_store_update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = current_store_id()::text
);

create policy "product_images_store_delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'product-images'
  and (storage.foldername(name))[1] = current_store_id()::text
);
