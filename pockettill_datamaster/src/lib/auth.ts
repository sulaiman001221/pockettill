import "server-only";
import { createSessionClient } from "@/lib/supabase/server";

export type AdminRole = "owner" | "editor" | "viewer";

export interface AdminProfile {
  id: string;
  email: string;
  fullName: string;
  role: AdminRole;
  /** Owners have this by default; Editors/Viewers can be granted it individually by an Owner. */
  canManageAccess: boolean;
}

/** Reads the currently logged-in admin's profile, or null if not signed in / not an active admin. */
export async function getCurrentAdmin(): Promise<AdminProfile | null> {
  const supabase = createSessionClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data } = await supabase
    .from("admin_users")
    .select("email, full_name, role, is_active, can_manage_access")
    .eq("id", user.id)
    .maybeSingle();

  if (!data?.is_active) return null;

  return {
    id: user.id,
    email: data.email,
    fullName: data.full_name || data.email,
    role: data.role as AdminRole,
    canManageAccess: data.can_manage_access,
  };
}

/** Owner and Editor can mutate store records; Viewer cannot. */
export function canManageStores(role: AdminRole): boolean {
  return role === "owner" || role === "editor";
}
