import "server-only";
import { unstable_cache } from "next/cache";
import type { AdminRole } from "@/lib/auth";
import { createServiceRoleClient } from "@/lib/supabase/server";

/** Tag used to bust every cached read in this file after an admin-account mutation. */
export const ADMIN_ACCOUNTS_CACHE_TAG = "admin-accounts";

export interface AdminUserRow {
  id: string;
  fullName: string;
  email: string;
  role: AdminRole;
  isActive: boolean;
  lastSignInAt: string | null;
  canManageAccess: boolean;
}

async function _getAdminUsersList(): Promise<AdminUserRow[]> {
  const supabase = createServiceRoleClient();

  const [{ data: admins, error }, { data: authList, error: authError }] = await Promise.all([
    supabase
      .from("admin_users")
      .select("id, email, full_name, role, is_active, can_manage_access")
      .order("created_at", { ascending: true }),
    supabase.auth.admin.listUsers(),
  ]);

  if (error) throw new Error(error.message);
  if (authError) throw new Error(authError.message);

  const lastSignInMap = new Map((authList?.users ?? []).map((u) => [u.id, u.last_sign_in_at ?? null]));

  return (admins ?? []).map((a) => ({
    id: a.id,
    fullName: a.full_name || a.email,
    email: a.email,
    role: a.role as AdminRole,
    isActive: a.is_active,
    lastSignInAt: lastSignInMap.get(a.id) ?? null,
    canManageAccess: a.can_manage_access,
  }));
}

export const getAdminUsersList = unstable_cache(_getAdminUsersList, ["admin-users-list"], {
  tags: [ADMIN_ACCOUNTS_CACHE_TAG],
  revalidate: 20,
});

export interface AuditLogEntry {
  id: string;
  adminName: string;
  action: string;
  target: string;
  createdAt: string;
}

interface AuditLogRow {
  id: string;
  action: string;
  target: string;
  created_at: string;
  admin_users: { full_name: string | null; email: string } | null;
}

async function _getAuditLog(): Promise<AuditLogEntry[]> {
  const supabase = createServiceRoleClient();
  const { data, error } = await supabase
    .from("audit_log")
    .select("id, action, target, created_at, admin_users(full_name, email)")
    .order("created_at", { ascending: false })
    .limit(500);

  if (error) throw new Error(error.message);

  return ((data ?? []) as unknown as AuditLogRow[]).map((r) => ({
    id: r.id,
    adminName: r.admin_users?.full_name || r.admin_users?.email || "Unknown",
    action: r.action,
    target: r.target,
    createdAt: r.created_at,
  }));
}

export const getAuditLog = unstable_cache(_getAuditLog, ["audit-log"], {
  tags: [ADMIN_ACCOUNTS_CACHE_TAG],
  revalidate: 20,
});
