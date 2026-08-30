"use client";

import { useRouter } from "next/navigation";
import { AlertOctagon, AlertTriangle, Bell } from "lucide-react";

import { Pagination } from "@/components/shared/pagination";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { usePagination } from "@/hooks/use-pagination";
import { cn } from "@/lib/utils";
import { formatDateTime, formatMaskedPhone } from "@/lib/format";
import type { SyncAlertStore, SyncSeverity } from "@/lib/data/sync-health";

const SEVERITY_CONFIG: Record<
  SyncSeverity,
  { label: string; badgeClass: string; icon: typeof AlertOctagon }
> = {
  critical: { label: "Critical", badgeClass: "bg-red-500/10 text-red-500", icon: AlertOctagon },
  warning: { label: "Warning", badgeClass: "bg-amber-500/10 text-amber-500", icon: AlertTriangle },
  nudge: { label: "Nudge", badgeClass: "bg-blue-500/10 text-blue-500", icon: Bell },
};

export interface SyncAlertRow extends SyncAlertStore {
  severity: SyncSeverity;
}

export function SyncAlertsTable({ alerts }: { alerts: SyncAlertRow[] }) {
  const router = useRouter();
  const { page, setPage, pageItems, pageSize, total } = usePagination(alerts, 10);

  return (
    <div className="flex flex-col gap-2">
      <div className="overflow-hidden rounded-xl bg-card ring-1 ring-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Severity</TableHead>
              <TableHead>Store</TableHead>
              <TableHead>Phone</TableHead>
              <TableHead>Last synced</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {pageItems.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} className="h-24 text-center text-muted-foreground">
                  All clear — no stores need attention.
                </TableCell>
              </TableRow>
            ) : (
              pageItems.map((alert) => {
                const config = SEVERITY_CONFIG[alert.severity];
                const Icon = config.icon;
                return (
                  <TableRow
                    key={alert.id}
                    className="cursor-pointer"
                    onClick={() => router.push(`/stores/${alert.id}`)}
                  >
                    <TableCell>
                      <Badge className={cn("gap-1 border-transparent", config.badgeClass)}>
                        <Icon className="size-3" />
                        {config.label}
                      </Badge>
                    </TableCell>
                    <TableCell className="font-medium">{alert.name}</TableCell>
                    <TableCell className="text-muted-foreground">
                      {formatMaskedPhone(alert.phone)}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {alert.lastSyncedAt ? formatDateTime(alert.lastSyncedAt) : "Never synced"}
                      {alert.daysSinceSync !== null ? ` · ${alert.daysSinceSync}d ago` : ""}
                    </TableCell>
                  </TableRow>
                );
              })
            )}
          </TableBody>
        </Table>
      </div>
      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
    </div>
  );
}
