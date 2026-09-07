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
  // barcode, so there's no principled way to pick a "best" one anyway.
  const { data: submitter } = await supabase
    .from("products")
    .select("store_id, image_url")
    .eq("barcode", barcode)
    .limit(1)
    .maybeSingle();

  // If the admin uploaded an enhanced replacement in the panel's "Enhanced
  // (Catalogue)" side, that becomes the catalogue image and the original
  // store submission is preserved separately for reference. Otherwise this
  // is unchanged from before the image-enhancement workflow existed - the
  // original submission is the catalogue image, nothing else to track.
  const enhancedImageUrl = options.enhancedImageUrl ?? null;
  const imageFields = enhancedImageUrl
    ? {
        image_url: enhancedImageUrl,
        original_image_url: submitter?.image_url ?? null,
        is_image_enhanced: true,
      }
    : {
        image_url: submitter?.image_url ?? null,
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
  if (options.enhancedImageUrl !== undefined) {
    const { data: existing } = await supabase
      .from("catalogue_products")
      .select("image_url, original_image_url, is_image_enhanced")
      .eq("barcode", barcode)
      .maybeSingle();

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
