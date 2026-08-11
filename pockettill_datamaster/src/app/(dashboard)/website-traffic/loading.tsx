import { PageHeader } from "@/components/shared/page-header";
import { ChartCardSkeleton, KpiCardsSkeleton, TableSkeleton } from "@/components/shared/skeletons";
import { Skeleton } from "@/components/ui/skeleton";

export default function WebsiteTrafficLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Website Traffic" description="Marketing site traffic via GA4." />
      <Skeleton className="h-9 w-56" />
      <KpiCardsSkeleton count={4} />
      <ChartCardSkeleton />
      <div className="grid gap-4 lg:grid-cols-2">
        <ChartCardSkeleton />
        <TableSkeleton rows={5} cols={2} />
      </div>
      <TableSkeleton rows={5} cols={2} />
    </div>
  );
}
