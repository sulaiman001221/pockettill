"use client";

import { useRouter } from "next/navigation";
import { AlertOctagon, AlertTriangle, Bell } from "lucide-react";

import { Pagination } from "@/components/shared/pagination";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { usePagination } from "@/hooks/use-pagination";
import { cn } from "@/lib/utils";
import { formatDateTime, formatMaskedPhone } from "@/lib/format";
import type { SyncAlertStore, SyncSeverity } from "@/lib/data/sync-health";

const SEVERITY_CONFIG: Record<
  SyncSeverity,
  { label: string; badgeClass: string; iconClass: string; icon: typeof AlertOctagon }
> = {
  critical: {
    label: "Critical",
    badgeClass: "bg-red-500/10 text-red-500",
    iconClass: "text-red-500",
    icon: AlertOctagon,
  },
  warning: {
    label: "Warning",
    badgeClass: "bg-amber-500/10 text-amber-500",
    iconClass: "text-amber-500",
    icon: AlertTriangle,
  },
  nudge: {
    label: "Nudge",
    badgeClass: "bg-blue-500/10 text-blue-500",
    iconClass: "text-blue-500",
    icon: Bell,
  },
};

export function AlertList({ severity, stores }: { severity: SyncSeverity; stores: SyncAlertStore[] }) {
  const router = useRouter();
  const config = SEVERITY_CONFIG[severity];
  const Icon = config.icon;
  const { page, setPage, pageItems, pageSize, total } = usePagination(stores, 5);

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between">
        <CardTitle className="flex items-center gap-1.5 text-base">
          <Icon className={cn("size-4", config.iconClass)} />
          {config.label}
        </CardTitle>
        <Badge className={cn("border-transparent", config.badgeClass)}>{stores.length}</Badge>
      </CardHeader>
      <CardContent className="flex flex-col gap-1 px-2">
        <div className="flex min-h-[15rem] flex-col gap-1">
          {pageItems.length === 0 ? (
            <p className="px-2 py-6 text-center text-sm text-muted-foreground">All clear.</p>
          ) : (
            pageItems.map((store) => (
              <button
                key={store.id}
                type="button"
                onClick={() => router.push(`/stores/${store.id}`)}
                className="flex flex-col gap-0.5 rounded-lg px-2 py-2 text-left text-sm transition-colors hover:bg-muted/50"
              >
                <span className="font-medium">{store.name}</span>
                <span className="text-xs text-muted-foreground">{formatMaskedPhone(store.phone)}</span>
                <span className="text-xs text-muted-foreground">
                  {store.lastSyncedAt ? formatDateTime(store.lastSyncedAt) : "Never synced"}
                  {store.daysSinceSync !== null ? ` · ${store.daysSinceSync}d ago` : ""}
                </span>
              </button>
            ))
          )}
        </div>
        <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
      </CardContent>
    </Card>
  );
}
