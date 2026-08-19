"use server";

import { revalidatePath, revalidateTag } from "next/cache";

import { logAudit } from "@/lib/audit";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { SUPPORT_CACHE_TAG, SUPPORT_STATUSES, type SupportStatus } from "@/lib/data/support";
import { createServiceRoleClient } from "@/lib/supabase/server";

export type SupportActionResult = { error?: string } | undefined;

/** Viewers can read enquiries but not work them, matching catalogue/store rules. */
async function requireSupportManager() {
  const admin = await getCurrentAdmin();
  if (!admin) throw new Error("Not authenticated.");
  if (!canManageStores(admin.role)) throw new Error("Not authorized to manage support enquiries.");
  return admin;
}

function revalidateSupport() {
  revalidateTag(SUPPORT_CACHE_TAG);
  revalidatePath("/support");
}

export async function updateSupportStatus(
  id: string,
  status: SupportStatus
): Promise<SupportActionResult> {
  let admin;
  try {
    admin = await requireSupportManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  if (!SUPPORT_STATUSES.includes(status)) {
    return { error: "Unknown status." };
  }

  const supabase = createServiceRoleClient();

  // Stamp who dealt with it once it leaves the "new" pile; clear the stamp if
  // it's pushed back to "new" so the record doesn't imply work that was undone.
  const handled = status === "new" ? null : admin.id;
  const handledAt = status === "new" ? null : new Date().toISOString();

  const { error } = await supabase
    .from("support_queries")
    .update({ status, handled_by: handled, handled_at: handledAt })
    .eq("id", id);

  if (error) return { error: error.message };

  await logAudit(admin.id, "support.status_changed", id, { status });

  revalidateSupport();
}

export async function saveSupportNotes(id: string, notes: string): Promise<SupportActionResult> {
  let admin;
  try {
    admin = await requireSupportManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const trimmed = notes.trim();
  if (trimmed.length > 4000) {
    return { error: "Notes are too long (4000 characters max)." };
  }

  const supabase = createServiceRoleClient();
  const { error } = await supabase
    .from("support_queries")
    .update({ internal_notes: trimmed || null })
    .eq("id", id);

  if (error) return { error: error.message };

  await logAudit(admin.id, "support.notes_updated", id);

  revalidateSupport();
}
