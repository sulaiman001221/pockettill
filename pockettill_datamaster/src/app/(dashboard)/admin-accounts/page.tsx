import { AdminUsersTable } from "@/components/admin-accounts/admin-users-table";
import { AuditLogTable } from "@/components/admin-accounts/audit-log-table";
import { InviteAdminDialog } from "@/components/admin-accounts/invite-admin-dialog";
import { PageHeader } from "@/components/shared/page-header";
import { getCurrentAdmin } from "@/lib/auth";
import { getAdminUsersList, getAuditLog } from "@/lib/data/admin-accounts";

export const metadata = { title: "Admin Accounts" };

export default async function AdminAccountsPage() {
  const [admins, auditLog, currentAdmin] = await Promise.all([
    getAdminUsersList(),
    getAuditLog(),
    getCurrentAdmin(),
  ]);

  const canManage = currentAdmin?.canManageAccess ?? false;
  const isOwner = currentAdmin?.role === "owner";

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Admin Accounts"
        description="Invite teammates and manage roles."
        actions={canManage ? <InviteAdminDialog /> : undefined}
      />

      <AdminUsersTable
        admins={admins}
        currentAdminId={currentAdmin?.id ?? ""}
        canManage={canManage}
        isOwner={isOwner}
      />

      <div className="flex flex-col gap-4">
        <h2 className="text-lg font-semibold">Audit Log</h2>
        <AuditLogTable entries={auditLog} />
      </div>
    </div>
  );
}
