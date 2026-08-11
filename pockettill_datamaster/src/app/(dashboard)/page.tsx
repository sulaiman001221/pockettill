import { AlertTriangle } from "lucide-react";
import { Suspense } from "react";
import { CheckCircle2, Globe, PackageCheck, Store, TrendingUp, Trophy } from "lucide-react";

import { WeeklyCostChart } from "@/components/infrastructure/weekly-cost-chart";
import { RegistrationsChart } from "@/components/overview/registrations-chart";
import { ForbiddenToast } from "@/components/shared/forbidden-toast";
import { KpiCard } from "@/components/shared/kpi-card";
import { PageHeader } from "@/components/shared/page-header";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getTwilioCostData } from "@/lib/costs/twilio";
import { getDailyRegistrations, getOverviewStats } from "@/lib/data/stores";
import { getWebsiteTrafficData } from "@/lib/integrations/ga4";

export const metadata = { title: "Overview" };

export default async function OverviewPage() {
  const [stats, registrations, twilioResult, trafficResult] = await Promise.all([
    getOverviewStats(),
    getDailyRegistrations(30),
    getTwilioCostData(),
    getWebsiteTrafficData(30),
  ]);

  const monthlyVisitors = trafficResult.status === "ok" ? trafficResult.data.kpis.totalUsers : 0;

  return (
    <div className="flex flex-col gap-6">
      <Suspense fallback={null}>
        <ForbiddenToast />
      </Suspense>

      <PageHeader title="Overview" description="Platform-wide KPIs and health at a glance." />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <KpiCard
          label="Active Stores"
          value={String(stats.activeStores)}
          icon={<Store className="size-4.5" />}
          tone="blue"
        />
        <KpiCard
          label="New This Month"
          value={String(stats.newThisMonth)}
          icon={<TrendingUp className="size-4.5" />}
          tone="emerald"
        />
        <KpiCard
          label="Founding Stores"
          value={`${stats.foundingStores} / ${stats.foundingCap}`}
          icon={<Trophy className="size-4.5" />}
          tone="amber"
        />
        <KpiCard
          label="Synced Last 24h"
          value={`${stats.syncedLast24hPct}%`}
          hint={`${stats.syncedLast24hCount} of ${stats.totalStores} stores`}
          icon={<CheckCircle2 className="size-4.5" />}
          tone="cyan"
        />
        <KpiCard
          label="Verified Products"
          value={String(stats.verifiedProducts)}
          icon={<PackageCheck className="size-4.5" />}
          tone="violet"
        />
        <KpiCard
          label="Website Traffic"
          value={String(monthlyVisitors)}
          hint="Monthly visitors"
          icon={<Globe className="size-4.5" />}
          tone="rose"
        />
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>New Store Registrations</CardTitle>
            <CardDescription>Daily signups over the last 30 days.</CardDescription>
          </CardHeader>
          <CardContent>
            <RegistrationsChart data={registrations} />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Weekly Infrastructure Costs</CardTitle>
            <CardDescription>Daily Twilio spend for the last 7 days.</CardDescription>
          </CardHeader>
          <CardContent>
            {twilioResult.status === "missing_config" ? (
              <p className="text-sm text-muted-foreground">
                Twilio isn&apos;t connected yet — see Infrastructure Costs for setup.
              </p>
            ) : twilioResult.status === "error" ? (
              <div className="flex items-center gap-2 rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-600 dark:text-amber-400">
                <AlertTriangle className="size-4 shrink-0" />
                Cost data is stale — the last request failed ({twilioResult.message}).
              </div>
            ) : twilioResult.data.dailySpend.length > 0 ? (
              <WeeklyCostChart data={twilioResult.data.dailySpend} />
            ) : (
              <p className="text-sm text-muted-foreground">No spend data available.</p>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
