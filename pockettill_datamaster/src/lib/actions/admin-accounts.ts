"use server";

import { headers } from "next/headers";
import { revalidatePath, revalidateTag } from "next/cache";

import { logAudit } from "@/lib/audit";
import { getCurrentAdmin, type AdminRole } from "@/lib/auth";
import { ADMIN_ACCOUNTS_CACHE_TAG } from "@/lib/data/admin-accounts";
import { createServiceRoleClient } from "@/lib/supabase/server";

export type AdminAccountActionResult = { error?: string } | undefined;

function siteOrigin() {
  const h = headers();
  return h.get("origin") ?? `https://${h.get("host")}`;
}

async function requireOwner() {
  const admin = await getCurrentAdmin();
  if (!admin) throw new Error("Not authenticated.");
  if (admin.role !== "owner") throw new Error("Only Owners can manage admin accounts.");
  return admin;
}

/** Invite/remove/role-change are gated by the can_manage_access flag, not role directly — Owners have it by default, but it can be extended to Editors/Viewers. */
async function requireAccessManager() {
  const admin = await getCurrentAdmin();
  if (!admin) throw new Error("Not authenticated.");
  if (!admin.canManageAccess) throw new Error("You don't have permission to manage admin accounts.");
  return admin;
}

export async function inviteAdmin(
  fullName: string,
  email: string,
  role: AdminRole
): Promise<AdminAccountActionResult> {
  let actor;
  try {
    actor = await requireAccessManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  const supabase = createServiceRoleClient();

  // This becomes the `next` destination baked into the Invite User email
  // template's /auth/confirm link (via {{ .RedirectTo }}) — see
  // src/app/auth/confirm/route.ts. It is NOT the literal link the admin
  // receives; the template builds that from {{ .TokenHash }}/{{ .Type }}.
  const { data, error } = await supabase.auth.admin.inviteUserByEmail(email, {
    redirectTo: `${siteOrigin()}/set-password`,
  });
  if (error || !data.user) {
    return { error: error?.message ?? "Failed to send invite." };
  }

  const { error: insertError } = await supabase.from("admin_users").insert({
    id: data.user.id,
    email,
    full_name: fullName,
    role,
    invited_by: actor.id,
    can_manage_access: role === "owner",
  });

  if (insertError) {
    return { error: insertError.message };
  }

  await logAudit(actor.id, "admin.invited", email, { role });

  revalidateTag(ADMIN_ACCOUNTS_CACHE_TAG);
  revalidatePath("/admin-accounts");
}

export async function toggleAdminActive(targetId: string, next: boolean): Promise<AdminAccountActionResult> {
  let actor;
  try {
    actor = await requireAccessManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  if (targetId === actor.id) {
    return { error: "You cannot deactivate your own account." };
  }

  const supabase = createServiceRoleClient();
  const { data: target } = await supabase.from("admin_users").select("email").eq("id", targetId).maybeSingle();

  const { error } = await supabase.from("admin_users").update({ is_active: next }).eq("id", targetId);
  if (error) return { error: error.message };

  await logAudit(actor.id, next ? "admin.reactivated" : "admin.deactivated", target?.email ?? targetId);

  revalidateTag(ADMIN_ACCOUNTS_CACHE_TAG);
  revalidatePath("/admin-accounts");
}

export async function changeAdminRole(targetId: string, newRole: AdminRole): Promise<AdminAccountActionResult> {
  let actor;
  try {
    actor = await requireAccessManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  if (targetId === actor.id) {
    return { error: "You cannot change your own role." };
  }

  const supabase = createServiceRoleClient();
  const { data: target } = await supabase
    .from("admin_users")
    .select("email, role")
    .eq("id", targetId)
    .maybeSingle();

  const updates: { role: AdminRole; can_manage_access?: boolean } = { role: newRole };
  if (newRole === "owner") {
    // Owners have can_manage_access by default.
    updates.can_manage_access = true;
  }

  const { error } = await supabase.from("admin_users").update(updates).eq("id", targetId);
  if (error) return { error: error.message };

  await logAudit(actor.id, "admin.role_changed", target?.email ?? targetId, {
    from: target?.role,
    to: newRole,
  });

  revalidateTag(ADMIN_ACCOUNTS_CACHE_TAG);
  revalidatePath("/admin-accounts");
}

export async function removeAdmin(targetId: string): Promise<AdminAccountActionResult> {
  let actor;
  try {
    actor = await requireAccessManager();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  if (targetId === actor.id) {
    return { error: "You cannot remove your own account." };
  }

  const supabase = createServiceRoleClient();
  const { data: target } = await supabase
    .from("admin_users")
    .select("email, role")
    .eq("id", targetId)
    .maybeSingle();

  if (target?.role === "owner" && actor.role !== "owner") {
    return { error: "Only Owners can remove another Owner." };
  }

  // Deletes the auth.users row; admin_users cascades via its FK to auth.users.
  const { error } = await supabase.auth.admin.deleteUser(targetId);
  if (error) return { error: error.message };

  await logAudit(actor.id, "admin.removed", target?.email ?? targetId);

  revalidateTag(ADMIN_ACCOUNTS_CACHE_TAG);
  revalidatePath("/admin-accounts");
}

/** Granting/revoking the "can manage access" permission itself is Owner-only, even though the permission it grants extends beyond Owners. */
export async function toggleCanManageAccess(
  targetId: string,
  next: boolean
): Promise<AdminAccountActionResult> {
  let owner;
  try {
    owner = await requireOwner();
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Not authorized." };
  }

  if (targetId === owner.id) {
    return { error: "You cannot change your own access permission." };
  }

  const supabase = createServiceRoleClient();
  const { data: target } = await supabase
    .from("admin_users")
    .select("email, role")
    .eq("id", targetId)
    .maybeSingle();

  if (!next && target?.role === "owner") {
    return { error: "Owners always have this permission — change their role first." };
  }

  const { error } = await supabase
    .from("admin_users")
    .update({ can_manage_access: next })
    .eq("id", targetId);
  if (error) return { error: error.message };

  await logAudit(
    owner.id,
    next ? "admin.access_granted" : "admin.access_revoked",
    target?.email ?? targetId
  );

  revalidateTag(ADMIN_ACCOUNTS_CACHE_TAG);
  revalidatePath("/admin-accounts");
}
