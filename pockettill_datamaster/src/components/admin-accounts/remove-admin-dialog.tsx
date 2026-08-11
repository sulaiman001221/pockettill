"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { removeAdmin } from "@/lib/actions/admin-accounts";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import type { AdminUserRow } from "@/lib/data/admin-accounts";

export function RemoveAdminDialog({
  admin,
  onOpenChange,
}: {
  admin: AdminUserRow | null;
  onOpenChange: (open: boolean) => void;
}) {
  const [pending, startTransition] = useTransition();

  function handleConfirm() {
    if (!admin) return;
    startTransition(async () => {
      const result = await removeAdmin(admin.id);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(`${admin.fullName} removed.`);
        onOpenChange(false);
      }
    });
  }

  return (
    <Dialog open={admin !== null} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Remove {admin?.fullName}?</DialogTitle>
          <DialogDescription>
            This permanently deletes their account. They will no longer be able to sign in, and this
            cannot be undone — unlike Deactivate, there&apos;s no way to restore access afterward.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button variant="destructive" disabled={pending} onClick={handleConfirm}>
            Remove permanently
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
