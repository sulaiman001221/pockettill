"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { toggleAdminActive } from "@/lib/actions/admin-accounts";
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

export function DeactivateAdminDialog({
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
      const result = await toggleAdminActive(admin.id, false);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(`${admin.fullName} deactivated.`);
        onOpenChange(false);
      }
    });
  }

  return (
    <Dialog open={admin !== null} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Deactivate {admin?.fullName}?</DialogTitle>
          <DialogDescription>
            They will immediately lose access to the dashboard. You can reactivate them at any time.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button variant="destructive" disabled={pending} onClick={handleConfirm}>
            Deactivate
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
