import { ActiveStoresChart } from "@/components/analytics/active-stores-chart";
import { SalesVolumeChart } from "@/components/analytics/sales-volume-chart";
import { TopCategoriesChart } from "@/components/catalogue/top-categories-chart";
import { RegistrationsChart } from "@/components/overview/registrations-chart";
import { DateRangeSelector } from "@/components/shared/date-range-selector";
import { DonutChart } from "@/components/shared/donut-chart";
import { PageHeader } from "@/components/shared/page-header";
import { SyncTrendChart } from "@/components/sync-health/sync-trend-chart";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getCategorySalesStats, getPaymentMethodSplit, getSalesDailyStats } from "@/lib/data/analytics";
import { getDailyRegistrations } from "@/lib/data/stores";
import { getSyncTrend } from "@/lib/data/sync-health";

export const metadata = { title: "Analytics" };

const VALID_RANGES = ["7", "30", "90"];

function capitalize(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export default async function AnalyticsPage({
  searchParams,
}: {
  searchParams: { range?: string };
}) {
  const range = VALID_RANGES.includes(searchParams.range ?? "") ? (searchParams.range as string) : "30";
  const days = Number(range);

  const [dailyStats, categories, paymentSplit, registrations, syncTrend] = await Promise.all([
    getSalesDailyStats(days),
    getCategorySalesStats(days),
    getPaymentMethodSplit(days),
    getDailyRegistrations(days),
    getSyncTrend(days),
  ]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Analytics" description="Aggregated platform-wide charts." />

      <DateRangeSelector value={range} />

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Daily Active Stores</CardTitle>
            <CardDescription>Distinct stores with at least one sale per day.</CardDescription>
          </CardHeader>
          <CardContent>
            <ActiveStoresChart data={dailyStats} />
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Sales Volume Trend</CardTitle>
            <CardDescription>Number of sales per day.</CardDescription>
          </CardHeader>
          <CardContent>
            <SalesVolumeChart data={dailyStats} />
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>Top Product Categories</CardTitle>
            <CardDescription>Units sold by category.</CardDescription>
          </CardHeader>
          <CardContent>
            {categories.length > 0 ? (
              <TopCategoriesChart
                data={categories.map((c) => ({ category: c.category, count: c.quantity }))}
              />
            ) : (
              <p className="text-sm text-muted-foreground">No sales in this period.</p>
            )}
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Payment Method Split</CardTitle>
            <CardDescription>Sales by payment type.</CardDescription>
          </CardHeader>
          <CardContent>
            {paymentSplit.length > 0 ? (
              <DonutChart data={paymentSplit.map((p) => ({ label: capitalize(p.method), value: p.count }))} />
            ) : (
              <p className="text-sm text-muted-foreground">No sales in this period.</p>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>New Store Registrations</CardTitle>
            <CardDescription>Daily signups.</CardDescription>
          </CardHeader>
          <CardContent>
            <RegistrationsChart data={registrations} />
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>Sync Health Over Time</CardTitle>
            <CardDescription>% of stores synced per day.</CardDescription>
          </CardHeader>
          <CardContent>
            <SyncTrendChart data={syncTrend} />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
