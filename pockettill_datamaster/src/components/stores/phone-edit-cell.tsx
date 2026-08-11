"use client";

import { useState, useTransition } from "react";
import { Check, Pencil, X } from "lucide-react";
import { toast } from "sonner";

import { updateStorePhone } from "@/lib/actions/stores";
import { formatMaskedPhone } from "@/lib/format";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";

export function PhoneEditCell({
  storeId,
  storeName,
  phone,
  canManage,
}: {
  storeId: string;
  storeName: string;
  phone: string;
  canManage: boolean;
}) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(phone);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [pending, startTransition] = useTransition();

  if (!canManage) {
    return <span>{formatMaskedPhone(phone)}</span>;
  }

  function handleConfirm() {
    startTransition(async () => {
      const result = await updateStorePhone(storeId, storeName, value);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success("Phone number updated.");
        setEditing(false);
        setConfirmOpen(false);
      }
    });
  }

  if (!editing) {
    return (
      <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
        <span>{formatMaskedPhone(phone)}</span>
        <Button
          variant="ghost"
          size="icon-sm"
          className="text-muted-foreground"
          onClick={() => {
            setValue(phone);
            setEditing(true);
          }}
        >
          <Pencil className="size-3.5" />
        </Button>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
      <Input
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="+27821234567"
        className="h-7 w-36"
        autoFocus
      />
      <Button variant="ghost" size="icon-sm" disabled={pending} onClick={() => setConfirmOpen(true)}>
        <Check className="size-3.5" />
      </Button>
      <Button variant="ghost" size="icon-sm" disabled={pending} onClick={() => setEditing(false)}>
        <X className="size-3.5" />
      </Button>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent onClick={(e) => e.stopPropagation()}>
          <DialogHeader>
            <DialogTitle>Update phone number?</DialogTitle>
            <DialogDescription>
              Change {storeName}&apos;s account-recovery number from {formatMaskedPhone(phone)} to{" "}
              <span className="font-medium text-foreground">{value}</span>. Make sure it&apos;s correct.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConfirmOpen(false)}>
              Cancel
            </Button>
            <Button disabled={pending} onClick={handleConfirm}>
              Confirm
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
