"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { DeactivateAdminDialog } from "@/components/admin-accounts/deactivate-admin-dialog";
import { RemoveAdminDialog } from "@/components/admin-accounts/remove-admin-dialog";
import { Pagination } from "@/components/shared/pagination";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { usePagination } from "@/hooks/use-pagination";
import { changeAdminRole, toggleAdminActive, toggleCanManageAccess } from "@/lib/actions/admin-accounts";
import type { AdminRole } from "@/lib/auth";
import type { AdminUserRow } from "@/lib/data/admin-accounts";
import { formatRelativeTime } from "@/lib/format";

const ROLE_LABELS: Record<AdminRole, string> = { owner: "Owner", editor: "Editor", viewer: "Viewer" };

export function AdminUsersTable({
  admins,
  currentAdminId,
  canManage,
  isOwner,
}: {
  admins: AdminUserRow[];
  currentAdminId: string;
  canManage: boolean;
  isOwner: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [deactivateTarget, setDeactivateTarget] = useState<AdminUserRow | null>(null);
  const [removeTarget, setRemoveTarget] = useState<AdminUserRow | null>(null);
  const { page, setPage, pageItems, pageSize, total } = usePagination(admins, 10);

  function handleRoleChange(admin: AdminUserRow, role: string) {
    startTransition(async () => {
      const result = await changeAdminRole(admin.id, role as AdminRole);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(`${admin.fullName}'s role updated to ${ROLE_LABELS[role as AdminRole]}.`);
      }
    });
  }

  function handleReactivate(admin: AdminUserRow) {
    startTransition(async () => {
      const result = await toggleAdminActive(admin.id, true);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(`${admin.fullName} reactivated.`);
      }
    });
  }

  function handleToggleAccess(admin: AdminUserRow, next: boolean) {
    startTransition(async () => {
      const result = await toggleCanManageAccess(admin.id, next);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(
          next
            ? `${admin.fullName} can now manage admin accounts.`
            : `${admin.fullName} can no longer manage admin accounts.`
        );
      }
    });
  }

  return (
    <>
      <div className="overflow-hidden rounded-xl bg-card ring-1 ring-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Email</TableHead>
              <TableHead>Role</TableHead>
              <TableHead>Can manage access</TableHead>
              <TableHead>Last login</TableHead>
              <TableHead>Status</TableHead>
              {canManage ? <TableHead className="text-right">Actions</TableHead> : null}
            </TableRow>
          </TableHeader>
          <TableBody>
            {pageItems.map((admin) => {
              const isSelf = admin.id === currentAdminId;
              return (
                <TableRow key={admin.id}>
                  <TableCell className="font-medium">
                    {admin.fullName}
                    {isSelf ? <span className="ml-1.5 text-xs text-muted-foreground">(you)</span> : null}
                  </TableCell>
                  <TableCell>{admin.email}</TableCell>
                  <TableCell>
                    <Select
                      value={admin.role}
                      onValueChange={(v) => v && handleRoleChange(admin, v)}
                      disabled={!canManage || isSelf || pending}
                    >
                      <SelectTrigger className="w-28" size="sm">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="owner">Owner</SelectItem>
                        <SelectItem value="editor">Editor</SelectItem>
                        <SelectItem value="viewer">Viewer</SelectItem>
                      </SelectContent>
                    </Select>
                  </TableCell>
                  <TableCell>
                    {isOwner ? (
                      <Switch
                        checked={admin.canManageAccess}
                        onCheckedChange={(next) => handleToggleAccess(admin, next)}
                        disabled={isSelf || admin.role === "owner" || pending}
                      />
                    ) : admin.canManageAccess ? (
                      <Badge variant="secondary">Yes</Badge>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </TableCell>
                  <TableCell>{formatRelativeTime(admin.lastSignInAt)}</TableCell>
                  <TableCell>
                    {admin.isActive ? (
                      <Badge className="border-transparent bg-emerald-500/10 text-emerald-500">Active</Badge>
                    ) : (
                      <Badge variant="outline">Inactive</Badge>
                    )}
                  </TableCell>
                  {canManage ? (
                    <TableCell className="text-right">
                      {isSelf ? null : (
                        <div className="flex justify-end gap-2">
                          {admin.isActive ? (
                            <Button
                              size="sm"
                              variant="outline"
                              disabled={pending}
                              onClick={() => setDeactivateTarget(admin)}
                            >
                              Deactivate
                            </Button>
                          ) : (
                            <Button
                              size="sm"
                              variant="outline"
                              disabled={pending}
                              onClick={() => handleReactivate(admin)}
                            >
                              Reactivate
                            </Button>
                          )}
                          <Button
                            size="sm"
                            variant="destructive"
                            disabled={pending}
                            onClick={() => setRemoveTarget(admin)}
                          >
                            Remove
                          </Button>
                        </div>
                      )}
                    </TableCell>
                  ) : null}
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </div>

      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />

      <DeactivateAdminDialog
        admin={deactivateTarget}
        onOpenChange={(open) => !open && setDeactivateTarget(null)}
      />
      <RemoveAdminDialog admin={removeTarget} onOpenChange={(open) => !open && setRemoveTarget(null)} />
    </>
  );
}
