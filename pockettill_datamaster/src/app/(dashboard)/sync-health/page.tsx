import { CheckCircle2, Clock, XCircle } from "lucide-react";

import { AlertList } from "@/components/sync-health/alert-list";
import { SyncTrendChart } from "@/components/sync-health/sync-trend-chart";
import { KpiCard } from "@/components/shared/kpi-card";
import { PageHeader } from "@/components/shared/page-header";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getSyncHealthData } from "@/lib/data/sync-health";
import { formatHours } from "@/lib/format";

export const metadata = { title: "Sync Health" };

export default async function SyncHealthPage() {
  const data = await getSyncHealthData();

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Sync Health"
        description="Stores that haven't synced recently, and sync trends over time."
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <AlertList severity="critical" stores={data.critical} />
        <AlertList severity="warning" stores={data.warning} />
        <AlertList severity="nudge" stores={data.nudge} />
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
