"use server";

import { revalidatePath, revalidateTag } from "next/cache";

import { logAudit } from "@/lib/audit";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { formatProductMass, formatProductName } from "@/lib/catalogue-format";
import { CATALOGUE_CACHE_TAG } from "@/lib/data/catalogue";
import { createServiceRoleClient } from "@/lib/supabase/server";

export type CatalogueActionResult = { error?: string } | undefined;

export type ApproveProductResult =
  | { error?: string; conflict?: undefined }
  | { conflict: { existingName: string }; error?: undefined }
  | undefined;

/**
 * Copies a store-submitted photo into the catalogue's own storage and returns
 * the copy's public URL (or [url] unchanged if it isn't a store-owned file or
 * the copy fails).
 *
 * The catalogue used to keep the submitting store's URL as-is, but a store's
 * photo lives at a fixed `{storeId}/{productUuid}.jpg` path that the store
 * overwrites in place on every re-upload - so replacing a photo in one store
 * silently changed the catalogue image and every other store that had copied
 * it (reported 2026-09-24). A unique, never-overwritten path per snapshot
 * makes the catalogue image immune to later edits in any store.
 */
async function snapshotStoreImage(
  supabase: ReturnType<typeof createServiceRoleClient>,
  url: string | null | undefined,
  barcode: string
): Promise<string | null> {
  if (!url) return null;
  const marker = "/storage/v1/object/public/product-images/";
  const at = url.indexOf(marker);
  if (at === -1) return url; // already a catalogue-owned (or external) URL

  const sourcePath = decodeURIComponent(url.slice(at + marker.length).split("?")[0]);
  const destPath = `originals/${barcode}-${Date.now()}.jpg`;
  try {
    const { data: blob, error: downloadError } = await supabase.storage
      .from("product-images")
      .download(sourcePath);
    if (downloadError || !blob) return url;
    const { error: uploadError } = await supabase.storage
      .from("catalogue-images")
      .upload(destPath, blob, { contentType: "image/jpeg", upsert: false });
    if (uploadError) return url;
    return supabase.storage.from("catalogue-images").getPublicUrl(destPath).data.publicUrl;
  } catch {
    return url;
  }
}

export interface ProductEdits {
  name: string;
  category: string;
  mass: string;
}

async function requireCatalogueManager() {
  const admin = await getCurrentAdmin();
  if (!admin) throw new Error("Not authenticated.");
  if (!canManageStores(admin.role)) throw new Error("Not authorized to manage the catalogue.");
  return admin;
}

export async function approveProduct(
  barcode: string,
  edits: ProductEdits,
  options: { force?: boolean; enhancedImageUrl?: string | null } = {}
): Promise<ApproveProductResult> {
  let admin;
  try {
    admin = await requireCatalogueManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const supabase = createServiceRoleClient();

  // The pending-review view already excludes any barcode that's already in
  // catalogue_products, so this is normally unreachable — but two admins
  // can race (one approves while the other still has a stale queue open),
  // so check again right before writing and let the admin choose rather
  // than silently overwriting whatever the other admin just approved.
  if (!options.force) {
    const { data: existing } = await supabase
      .from("catalogue_products")
      .select("name")
      .eq("barcode", barcode)
      .maybeSingle();

    if (existing) {
      return { conflict: { existingName: existing.name } };
    }
  }

  // Authoritative formatting pass: the panel pre-formats on open so the
  // admin isn't surprised by a diff, but this is the only step that can't
  // be bypassed by client state — it re-runs on whatever the admin actually
  // submitted, catching manual edits that don't follow the convention.
  const name = formatProductName(edits.name);
  const mass = formatProductMass(edits.mass);

  // Attribution (store_id) and image are both "any one submission" picks,
  // not "the most common" - same simplification, just extended to image_url
  // when this column was added. A store's own photo of a specific unit
  // isn't canonically "more correct" than another store's for the same
  // barcode, so there's no principled way to pick a "best" one anyway -
  // *between two submissions that both have a photo*. Between one that has
  // one and one that doesn't, there is a clear best pick, and the plain
  // `.limit(1)` this used to be gave Postgres no ordering to go on at all,
  // so it could - and did - just as easily return the submission with no
  // photo, approving the barcode into the catalogue with no image even
  // though another store's real photo of it was sitting right there. Found
  // 2026-09-23 on "B Well Pure Canola Oil": two submissions existed, one
  // photographed, one not, and the no-photo one got picked. `nullsFirst:
  // false` only changes where NULLs sort, not which non-null one wins when
  // more than one has a photo - still an arbitrary, undocumented pick,
  // same as before.
  const { data: submitter } = await supabase
    .from("products")
    .select("store_id, image_url")
    .eq("barcode", barcode)
    .order("image_url", { ascending: true, nullsFirst: false })
    .limit(1)
    .maybeSingle();

  // If the admin uploaded an enhanced replacement in the panel's "Enhanced
  // (Catalogue)" side, that becomes the catalogue image and the original
  // store submission is preserved separately for reference. Otherwise this
  // is unchanged from before the image-enhancement workflow existed - the
  // original submission is the catalogue image, nothing else to track.
  const enhancedImageUrl = options.enhancedImageUrl ?? null;
  const originalImageUrl = await snapshotStoreImage(supabase, submitter?.image_url, barcode);
  const imageFields = enhancedImageUrl
    ? {
        image_url: enhancedImageUrl,
        original_image_url: originalImageUrl,
        is_image_enhanced: true,
      }
    : {
        image_url: originalImageUrl,
        original_image_url: null,
        is_image_enhanced: false,
      };

  const { error } = await supabase.from("catalogue_products").upsert({
    barcode,
    name,
    category: edits.category,
    mass,
    ...imageFields,
    verified_at: new Date().toISOString(),
    submitted_by_store_id: submitter?.store_id ?? null,
  });

  if (error) return { error: error.message };

  await logAudit(admin.id, "product.approved", barcode, { name, category: edits.category });

  revalidateTag(CATALOGUE_CACHE_TAG);
  revalidatePath("/product-catalogue");
}

/** Max upload accepted for an admin-enhanced catalogue image - generous since,
 * unlike a store owner's on-device upload, this never needs to fit a mobile
 * data budget itself; the Flutter app compresses it down to ~50KB locally
 * when it caches it for offline display. */
const MAX_ENHANCED_IMAGE_BYTES = 10 * 1024 * 1024;

/**
 * Uploads an admin-enhanced replacement photo for [barcode] to the
 * `catalogue-images` bucket (public-read, admin-write-only - see
 * SCHEMA_TRUTH.md) and returns its public URL. Does **not** write anything to
 * `catalogue_products` itself - the panel calls this immediately on file
 * pick so the admin sees a preview right away, and only [approveProduct] /
 * [updateVerifiedProduct] committing that URL makes it the catalogue image.
 * Backing out of the panel after an upload just leaves an orphaned object at
 * that path until the next successful upload for the same barcode replaces
 * it - not worth guarding against for an admin-only tool.
 */
export async function uploadEnhancedCatalogueImage(
  barcode: string,
  formData: FormData
): Promise<{ url?: string; error?: string }> {
  try {
    await requireCatalogueManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const file = formData.get("file");
  if (!(file instanceof File)) {
    return { error: "No file provided." };
  }
  if (!file.type.startsWith("image/")) {
    return { error: "File must be an image." };
  }
  if (file.size > MAX_ENHANCED_IMAGE_BYTES) {
    return { error: "Image must be smaller than 10MB." };
  }

  const supabase = createServiceRoleClient();
  const bytes = new Uint8Array(await file.arrayBuffer());
  // Path always ends .jpg by convention (matching product-images), even
  // though the admin may have picked a PNG/WEBP - the stored Content-Type
  // header is what browsers/Image.network actually use to decode it, not
  // the URL's extension.
  const path = `${barcode}.jpg`;

  const { error } = await supabase.storage
    .from("catalogue-images")
    .upload(path, bytes, { contentType: file.type, upsert: true });

  if (error) return { error: error.message };

  const { data } = supabase.storage.from("catalogue-images").getPublicUrl(path);
  // Cache-bust: re-uploading to the same path returns the same public URL,
  // so without this the browser's (and the Flutter app's) image cache would
  // keep showing the previous enhanced version - same fix as
  // ProductImageService.uploadProductImage in the Flutter app.
  return { url: `${data.publicUrl}?v=${Date.now()}` };
}

export async function rejectProduct(barcode: string): Promise<CatalogueActionResult> {
  let admin;
  try {
    admin = await requireCatalogueManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  // No is_verified filter needed - products no longer carries that concept,
  // and this action is only ever reachable from the pending-review panel,
  // which by construction only lists barcodes with no catalogue_products
  // entry yet.
  const supabase = createServiceRoleClient();
  const { error } = await supabase.from("products").delete().eq("barcode", barcode);

  if (error) return { error: error.message };

  // Deleting the `products` rows above isn't durable on its own: a store
  // that still has this barcode in its own local Stock will re-push a
  // fresh `products` row the moment it touches that product again at all
  // (a sale, a stock/price edit), silently resurrecting the barcode in the
  // pending queue. This denylist is what actually makes "rejected" stick -
  // pending_catalogue_items excludes anything in it, permanently, no matter
  // what any store's device does afterward.
  const { error: denylistError } = await supabase
    .from("rejected_catalogue_barcodes")
    .upsert({ barcode, rejected_by: admin.id, rejected_at: new Date().toISOString() });

  if (denylistError) return { error: denylistError.message };

  await logAudit(admin.id, "product.rejected", barcode);

  revalidateTag(CATALOGUE_CACHE_TAG);
  revalidatePath("/product-catalogue");
}

export async function updateVerifiedProduct(
  barcode: string,
  edits: ProductEdits,
  options: { enhancedImageUrl?: string | null } = {}
): Promise<CatalogueActionResult> {
  try {
    await requireCatalogueManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const supabase = createServiceRoleClient();

  const update: Record<string, unknown> = {
    name: edits.name,
    category: edits.category,
    mass: edits.mass,
    updated_at: new Date().toISOString(),
  };

  // options.enhancedImageUrl is `undefined` unless the admin actually
  // touched the Enhanced panel this edit (upload OR Clear) - a plain
  // name/category/mass correction never touches the image columns at all.
  // `null` specifically means Clear was clicked: revert to the plain
  // original rather than being silently skipped (which is what a bare
  // truthy check on this field used to do - Clear looked like it did
  // nothing, found 2026-09-08).
  //
  // Declared outside the `if` (rather than the previous inline `const`) so
  // the cascade fix below can still read what the image URL *was* before
  // this edit replaces it - see that comment for why.
  let existing: { image_url: string | null; original_image_url: string | null; is_image_enhanced: boolean } | null = null;
  if (options.enhancedImageUrl !== undefined) {
    const { data } = await supabase
      .from("catalogue_products")
      .select("image_url, original_image_url, is_image_enhanced")
      .eq("barcode", barcode)
      .maybeSingle();
    existing = data;

    if (options.enhancedImageUrl === null) {
      update.image_url = existing?.original_image_url ?? existing?.image_url ?? null;
      update.original_image_url = null;
      update.is_image_enhanced = false;
    } else {
      update.image_url = options.enhancedImageUrl;
      update.is_image_enhanced = true;
      // The true original is captured once and never overwritten by a
      // later re-enhancement - only set it the first time an enhanced
      // image replaces a plain one; a second enhanced upload just
      // replaces the enhanced version, not what it was enhancing.
      if (!existing?.is_image_enhanced) {
        update.original_image_url = existing?.image_url ?? null;
      }
    }
  }

  const { error } = await supabase.from("catalogue_products").update(update).eq("barcode", barcode);

  if (error) return { error: error.message };

  // A store's own `products.image_url` is a one-time copy taken whenever
  // that store's app happened to sync in this barcode's catalogue image -
  // changing it here doesn't retroactively touch any store that already has
  // the old value. Each store's app *can* notice on its own next background
  // image sync (see the Flutter app's ImageSyncService), but only if
  // `is_image_enhanced` was true and is now false - a plain re-upload
  // (enhanced replacing enhanced) isn't covered by that check at all, and
  // even the covered case depends on that specific device's own local
  // bookkeeping and next sync timing, which found 2026-09-23 a real store
  // permanently stuck showing a wrong photo (uploaded for the wrong barcode
  // by mistake, later cleared here) with nothing to fix it. Correcting
  // every store's copy directly, right here, is the only guarantee - a
  // plain column update, not a stock/balance write, so it isn't subject to
  // the Flutter app's server-owned-field guards.
  const oldImageUrl = options.enhancedImageUrl !== undefined ? existing?.image_url : undefined;
  if (oldImageUrl && oldImageUrl !== update.image_url) {
    await supabase
      .from("products")
      .update({ image_url: update.image_url })
      .eq("barcode", barcode)
      .eq("image_url", oldImageUrl);
  }

  revalidateTag(CATALOGUE_CACHE_TAG);
  revalidatePath("/product-catalogue");
}

export async function unverifyProduct(barcode: string): Promise<CatalogueActionResult> {
  try {
    await requireCatalogueManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  // Removes it from the shared catalogue entirely (rather than flipping a
  // flag, which no longer exists) - any store that still has this barcode
  // in its own inventory correctly reappears in the pending-review list.
  const supabase = createServiceRoleClient();
  const { error } = await supabase.from("catalogue_products").delete().eq("barcode", barcode);

  if (error) return { error: error.message };

  revalidateTag(CATALOGUE_CACHE_TAG);
  revalidatePath("/product-catalogue");
}
