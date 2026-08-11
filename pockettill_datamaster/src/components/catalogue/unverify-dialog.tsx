"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { unverifyProduct } from "@/lib/actions/catalogue";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

export function UnverifyDialog({
  barcode,
  onOpenChange,
}: {
  barcode: string | null;
  onOpenChange: (open: boolean) => void;
}) {
  const [pending, startTransition] = useTransition();

  function handleRemove() {
    if (!barcode) return;
    startTransition(async () => {
      const result = await unverifyProduct(barcode);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success("Moved back to the verification queue.");
        onOpenChange(false);
      }
    });
  }

  return (
    <Dialog open={barcode !== null} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Remove from verified catalogue?</DialogTitle>
          <DialogDescription>
            This sends barcode {barcode} back to the Verification Queue for every store. It is not deleted.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button variant="destructive" disabled={pending} onClick={handleRemove}>
            Remove
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
