"use server";

import { revalidatePath, revalidateTag } from "next/cache";

import { logAudit } from "@/lib/audit";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { formatProductMass, formatProductName } from "@/lib/catalogue-format";
import { CATALOGUE_CACHE_TAG } from "@/lib/data/catalogue";
import { createServiceRoleClient } from "@/lib/supabase/server";

export type CatalogueActionResult = { error?: string } | undefined;

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

export async function approveProduct(barcode: string, edits: ProductEdits): Promise<CatalogueActionResult> {
  let admin;
  try {
    admin = await requireCatalogueManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  // Authoritative formatting pass: the panel pre-formats on open so the
  // admin isn't surprised by a diff, but this is the only step that can't
  // be bypassed by client state — it re-runs on whatever the admin actually
  // submitted, catching manual edits that don't follow the convention.
  const name = formatProductName(edits.name);
  const mass = formatProductMass(edits.mass);

  const supabase = createServiceRoleClient();

  // Attribution only, for admin reference - picks any one of the store(s)
  // that had this barcode pending, since the review panel aggregates
  // submissions across every store that independently added it.
  const { data: submitter } = await supabase
    .from("products")
    .select("store_id")
    .eq("barcode", barcode)
    .limit(1)
    .maybeSingle();

  const { error } = await supabase.from("catalogue_products").upsert({
    barcode,
    name,
    category: edits.category,
    mass,
    verified_at: new Date().toISOString(),
    submitted_by_store_id: submitter?.store_id ?? null,
  });

  if (error) return { error: error.message };

  await logAudit(admin.id, "product.approved", barcode, { name, category: edits.category });

  revalidateTag(CATALOGUE_CACHE_TAG);
  revalidatePath("/product-catalogue");
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

  await logAudit(admin.id, "product.rejected", barcode);

  revalidateTag(CATALOGUE_CACHE_TAG);
  revalidatePath("/product-catalogue");
}

export async function updateVerifiedProduct(
  barcode: string,
  edits: ProductEdits
): Promise<CatalogueActionResult> {
  try {
    await requireCatalogueManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const supabase = createServiceRoleClient();
  const { error } = await supabase
    .from("catalogue_products")
    .update({
      name: edits.name,
      category: edits.category,
      mass: edits.mass,
      updated_at: new Date().toISOString(),
    })
    .eq("barcode", barcode);

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
