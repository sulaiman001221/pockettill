-- Public-read bucket for admin-uploaded "enhanced" catalogue product photos
-- (pockettill_datamaster's verification-queue image-enhancement workflow).
-- Path convention: {barcode}.jpg - one enhanced image per canonical
-- catalogue barcode, replacing on re-upload same as product-images does.
-- No insert/update/delete policy for anon/authenticated at all, by design -
-- only pockettill_datamaster's service-role client (which bypasses RLS
-- entirely) ever writes here, mirroring catalogue_products' own
-- admin-write-only posture.
insert into storage.buckets (id, name, public)
values ('catalogue-images', 'catalogue-images', true)
on conflict (id) do nothing;

create policy "catalogue_images_public_read"
on storage.objects for select
to public
using (bucket_id = 'catalogue-images');
