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
  const { error } = await supabase
    .from("products")
    .update({
      is_verified: true,
      name,
      category: edits.category,
      mass,
      verified_at: new Date().toISOString(),
    })
    .eq("barcode", barcode);

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

  const supabase = createServiceRoleClient();
  const { error } = await supabase.from("products").delete().eq("barcode", barcode).eq("is_verified", false);

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
    .from("products")
    .update({ name: edits.name, category: edits.category, mass: edits.mass })
    .eq("barcode", barcode)
    .eq("is_verified", true);

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

  const supabase = createServiceRoleClient();
  const { error } = await supabase.from("products").update({ is_verified: false }).eq("barcode", barcode);

  if (error) return { error: error.message };

  revalidateTag(CATALOGUE_CACHE_TAG);
  revalidatePath("/product-catalogue");
}
