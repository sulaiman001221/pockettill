"use client";

import { useState, useTransition } from "react";
import { toast } from "sonner";

import { toggleFoundingStore, toggleStoreActive } from "@/lib/actions/stores";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";

export function StoreActions({
  storeId,
  storeName,
  isFounding,
  active,
}: {
  storeId: string;
  storeName: string;
  isFounding: boolean;
  active: boolean;
}) {
  const [pending, startTransition] = useTransition();
  const [confirmOpen, setConfirmOpen] = useState(false);

  function handleToggleFounding() {
    startTransition(async () => {
      const result = await toggleFoundingStore(storeId, storeName, !isFounding);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(isFounding ? "Removed founding status." : "Granted founding status.");
      }
    });
  }

  function handleToggleActive() {
    startTransition(async () => {
      const result = await toggleStoreActive(storeId, storeName, !active);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(active ? "Store deactivated." : "Store reactivated.");
        setConfirmOpen(false);
      }
    });
  }

  return (
    <div className="flex flex-wrap gap-2">
      <Button variant="outline" disabled={pending} onClick={handleToggleFounding}>
        {isFounding ? "Remove Founding Status" : "Grant Founding Status"}
      </Button>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogTrigger
          render={<Button variant={active ? "destructive" : "outline"} disabled={pending} />}
        >
          {active ? "Deactivate Account" : "Reactivate Account"}
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{active ? "Deactivate this store?" : "Reactivate this store?"}</DialogTitle>
            <DialogDescription>
              {active
                ? "The store owner will immediately lose access to the platform. You can reactivate at any time."
                : "The store owner will regain access to the platform."}
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose render={<Button variant="outline" />}>Cancel</DialogClose>
            <Button
              variant={active ? "destructive" : "default"}
              disabled={pending}
              onClick={handleToggleActive}
            >
              {active ? "Deactivate" : "Reactivate"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
