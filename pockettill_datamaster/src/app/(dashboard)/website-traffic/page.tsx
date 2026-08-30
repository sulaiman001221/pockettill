import { Clock, Eye, LogOut, Users } from "lucide-react";

import { DateRangeSelector } from "@/components/shared/date-range-selector";
import { InfraErrorBanner } from "@/components/shared/infra-error-banner";
import { KpiCard } from "@/components/shared/kpi-card";
import { DonutChart } from "@/components/shared/donut-chart";
import { PageHeader } from "@/components/shared/page-header";
import { TopCountriesTable } from "@/components/website-traffic/top-countries-table";
import { TopPagesTable } from "@/components/website-traffic/top-pages-table";
import { TrafficSetupPanel } from "@/components/website-traffic/traffic-setup-panel";
import { VisitorsChart } from "@/components/website-traffic/visitors-chart";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { retryWebsiteTraffic } from "@/lib/actions/infrastructure";
import { getWebsiteTrafficData } from "@/lib/integrations/ga4";
import { formatDurationSec } from "@/lib/format";

export const metadata = { title: "Website Traffic" };

const VALID_RANGES = ["7", "30", "90"];

export default async function WebsiteTrafficPage({
  searchParams,
}: {
  searchParams: { range?: string };
}) {
  const range = VALID_RANGES.includes(searchParams.range ?? "") ? (searchParams.range as string) : "30";
  const result = await getWebsiteTrafficData(Number(range));

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Website Traffic" description="Marketing site traffic via GA4." />

      {result.status === "missing_config" ? (
        <TrafficSetupPanel />
      ) : result.status === "error" ? (
        <InfraErrorBanner message={result.message} onRetry={retryWebsiteTraffic} />
      ) : (
        <>
          <DateRangeSelector value={range} />

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <KpiCard
              label="Total Visitors"
              value={String(result.data.kpis.totalUsers)}
              icon={<Users className="size-4.5" />}
              tone="blue"
            />
            <KpiCard
              label="Page Views"
              value={String(result.data.kpis.screenPageViews)}
              icon={<Eye className="size-4.5" />}
              tone="violet"
            />
            <KpiCard
              label="Bounce Rate"
              value={`${result.data.kpis.bounceRatePct.toFixed(1)}%`}
              icon={<LogOut className="size-4.5" />}
              tone="amber"
            />
            <KpiCard
              label="Avg Session Duration"
              value={formatDurationSec(result.data.kpis.avgSessionDurationSec)}
              icon={<Clock className="size-4.5" />}
              tone="emerald"
            />
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Visitors Over Time</CardTitle>
              <CardDescription>Daily visitors for the selected period.</CardDescription>
            </CardHeader>
            <CardContent>
              <VisitorsChart data={result.data.dailyVisitors} />
            </CardContent>
          </Card>

          <div className="grid gap-4 lg:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Traffic Sources</CardTitle>
              </CardHeader>
              <CardContent>
                {result.data.channelSplit.length > 0 ? (
                  <DonutChart
                    data={result.data.channelSplit.map((c) => ({ label: c.channel, value: c.sessions }))}
                  />
                ) : (
                  <p className="text-sm text-muted-foreground">No sessions yet.</p>
                )}
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle>Top Pages</CardTitle>
              </CardHeader>
              <CardContent className="px-0">
                <TopPagesTable pages={result.data.topPages} />
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardHeader>
              <CardTitle>Top Countries</CardTitle>
            </CardHeader>
            <CardContent className="px-0">
              <TopCountriesTable countries={result.data.topCountries} />
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}
