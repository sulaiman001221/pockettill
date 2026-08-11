"use client";

import { useTransition } from "react";
import { toast } from "sonner";

import { toggleFoundingStore } from "@/lib/actions/stores";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";

export function FoundingToggleCell({
  storeId,
  storeName,
  isFounding,
  canManage,
}: {
  storeId: string;
  storeName: string;
  isFounding: boolean;
  canManage: boolean;
}) {
  const [pending, startTransition] = useTransition();

  if (!canManage) {
    return isFounding ? (
      <Badge variant="secondary">Founding</Badge>
    ) : (
      <span className="text-muted-foreground">—</span>
    );
  }

  function handleToggle(next: boolean) {
    startTransition(async () => {
      const result = await toggleFoundingStore(storeId, storeName, next);
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success(next ? "Granted founding status." : "Removed founding status.");
      }
    });
  }

  return (
    <div onClick={(e) => e.stopPropagation()}>
      <Switch checked={isFounding} onCheckedChange={handleToggle} disabled={pending} />
    </div>
  );
}
