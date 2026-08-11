"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { rejectProduct } from "@/lib/actions/catalogue";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";

export function RejectDialog({
  barcode,
  onOpenChange,
}: {
  barcode: string | null;
  onOpenChange: (open: boolean) => void;
}) {
  const [pending, startTransition] = useTransition();

  function handleReject() {
    if (!barcode) return;
    startTransition(async () => {
      const result = await rejectProduct(barcode);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success("Submission rejected.");
        onOpenChange(false);
      }
    });
  }

  return (
    <Dialog open={barcode !== null} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Reject this submission?</DialogTitle>
          <DialogDescription>
            This permanently deletes every pending row for barcode {barcode} across all stores. This
            cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button variant="destructive" disabled={pending} onClick={handleReject}>
            Reject
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
