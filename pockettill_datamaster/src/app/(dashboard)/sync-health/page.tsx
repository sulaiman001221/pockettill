import { AlertOctagon, AlertTriangle, Bell, CheckCircle2, Clock, XCircle } from "lucide-react";

import { SyncAlertsTable, type SyncAlertRow } from "@/components/sync-health/sync-alerts-table";
import { SyncTrendChart } from "@/components/sync-health/sync-trend-chart";
import { KpiCard } from "@/components/shared/kpi-card";
import { PageHeader } from "@/components/shared/page-header";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getSyncHealthData } from "@/lib/data/sync-health";
import { formatHours } from "@/lib/format";

export const metadata = { title: "Sync Health" };

export default async function SyncHealthPage() {
  const data = await getSyncHealthData();

  // Alert lists are already sorted stalest-first within each severity;
  // concatenating in critical -> warning -> nudge order keeps the most
  // urgent stores at the top of the combined list.
  const alerts: SyncAlertRow[] = [
    ...data.critical.map((s) => ({ ...s, severity: "critical" as const })),
    ...data.warning.map((s) => ({ ...s, severity: "warning" as const })),
    ...data.nudge.map((s) => ({ ...s, severity: "nudge" as const })),
  ];

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Sync Health"
        description="Stores that haven't synced recently, and sync trends over time."
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <KpiCard
          label="Critical"
          value={String(data.critical.length)}
          icon={<AlertOctagon className="size-4.5" />}
          tone="rose"
        />
        <KpiCard
          label="Warning"
          value={String(data.warning.length)}
          icon={<AlertTriangle className="size-4.5" />}
          tone="amber"
        />
        <KpiCard
          label="Nudge"
          value={String(data.nudge.length)}
          icon={<Bell className="size-4.5" />}
          tone="blue"
        />
        <KpiCard
          label="Never Synced"
          value={String(data.neverSyncedCount)}
          icon={<XCircle className="size-4.5" />}
          tone="rose"
        />
        <KpiCard
          label="Median Sync Gap"
          value={formatHours(data.medianSyncGapHours)}
          icon={<Clock className="size-4.5" />}
          tone="blue"
        />
        <KpiCard
          label="Synced Last 24h"
          value={`${data.syncedLast24hPct}%`}
          hint={`${data.syncedLast24hCount} of ${data.totalStores} stores`}
          icon={<CheckCircle2 className="size-4.5" />}
          tone="emerald"
        />
      </div>

      <SyncAlertsTable alerts={alerts} />

      <Card>
        <CardHeader>
          <CardTitle>Sync Trend</CardTitle>
          <CardDescription>% of stores that synced each day, last 30 days.</CardDescription>
        </CardHeader>
        <CardContent>
          <SyncTrendChart data={data.dailyTrend} />
        </CardContent>
      </Card>
    </div>
  );
}
