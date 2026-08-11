import { ChartCardSkeleton, KpiCardsSkeleton } from "@/components/shared/skeletons";
import { PageHeader } from "@/components/shared/page-header";

export default function OverviewLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Overview" description="Platform-wide KPIs and health at a glance." />
      <KpiCardsSkeleton count={6} />
      <div className="grid gap-4 lg:grid-cols-2">
        <ChartCardSkeleton />
        <ChartCardSkeleton />
      </div>
    </div>
  );
}
