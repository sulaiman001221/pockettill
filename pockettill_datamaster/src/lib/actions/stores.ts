"use server";

import { revalidatePath, revalidateTag } from "next/cache";

import { logAudit } from "@/lib/audit";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { STORES_CACHE_TAG } from "@/lib/data/stores";
import { createServiceRoleClient } from "@/lib/supabase/server";

export type StoreActionResult = { error?: string } | undefined;

async function requireStoreManager() {
  const admin = await getCurrentAdmin();
  if (!admin) throw new Error("Not authenticated.");
  if (!canManageStores(admin.role)) throw new Error("Not authorized to manage stores.");
  return admin;
}

export async function toggleFoundingStore(
  storeId: string,
  storeName: string,
  next: boolean
): Promise<StoreActionResult> {
  let admin;
  try {
    admin = await requireStoreManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const supabase = createServiceRoleClient();
  const { error } = await supabase.from("stores").update({ is_beta_adopter: next }).eq("uuid", storeId);

  if (error) return { error: error.message };

  await logAudit(admin.id, "store.founding_toggled", storeName, { storeId, foundingStatus: next });

  revalidateTag(STORES_CACHE_TAG);
  revalidatePath(`/stores/${storeId}`);
  revalidatePath("/stores");
}

export async function toggleStoreActive(
  storeId: string,
  storeName: string,
  next: boolean
): Promise<StoreActionResult> {
  let admin;
  try {
    admin = await requireStoreManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const supabase = createServiceRoleClient();
  const { error } = await supabase.from("stores").update({ active: next }).eq("uuid", storeId);

  if (error) return { error: error.message };

  await logAudit(admin.id, next ? "store.reactivated" : "store.deactivated", storeName, { storeId });

  revalidateTag(STORES_CACHE_TAG);
  revalidatePath(`/stores/${storeId}`);
  revalidatePath("/stores");
}

function normalizeSaPhone(raw: string): string | null {
  const digits = raw.replace(/[^\d+]/g, "");
  const withCountryCode = digits.startsWith("0")
    ? `+27${digits.slice(1)}`
    : digits.startsWith("+27")
      ? digits
      : digits.startsWith("27")
        ? `+${digits}`
        : null;
  return withCountryCode && /^\+27\d{9}$/.test(withCountryCode) ? withCountryCode : null;
}

export async function updateStorePhone(
  storeId: string,
  storeName: string,
  newPhone: string
): Promise<StoreActionResult> {
  let admin;
  try {
    admin = await requireStoreManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const normalized = normalizeSaPhone(newPhone);
  if (!normalized) {
    return { error: "Enter a valid South African phone number." };
  }

  const supabase = createServiceRoleClient();
  const { error } = await supabase.from("stores").update({ owner_phone: normalized }).eq("uuid", storeId);

  if (error) return { error: error.message };

  await logAudit(admin.id, "store.phone_updated", storeName, { storeId });

  revalidateTag(STORES_CACHE_TAG);
  revalidatePath(`/stores/${storeId}`);
  revalidatePath("/stores");
}
