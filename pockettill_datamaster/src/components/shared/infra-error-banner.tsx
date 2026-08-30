"use client";

import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { AlertTriangle, RefreshCw } from "lucide-react";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

export function InfraErrorBanner({
  message,
  onRetry,
}: {
  message: string;
  onRetry: () => Promise<void>;
}) {
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  function handleRetry() {
    startTransition(async () => {
      await onRetry();
      router.refresh();
    });
  }

  return (
    <div className="flex items-center justify-between gap-3 rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-600 dark:text-amber-400">
      <div className="flex items-center gap-2">
        <AlertTriangle className="size-4 shrink-0" />
        <span>Data is stale — the last request failed ({message}).</span>
      </div>
      <Button size="sm" variant="outline" onClick={handleRetry} disabled={pending} className="shrink-0">
        <RefreshCw className={cn("size-3.5", pending && "animate-spin")} />
        Retry
      </Button>
    </div>
  );
}
