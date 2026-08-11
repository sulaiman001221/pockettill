import { PageHeader } from "@/components/shared/page-header";
import { ChartCardSkeleton, KpiCardsSkeleton, TableSkeleton } from "@/components/shared/skeletons";
import { Skeleton } from "@/components/ui/skeleton";

export default function InfrastructureCostsLoading() {
  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title="Infrastructure Costs"
        description="Read-only usage and cost tracking for platform services."
      />

      <div className="flex flex-col gap-4">
        <Skeleton className="h-6 w-24" />
        <KpiCardsSkeleton count={4} />
      </div>

      <div className="flex flex-col gap-4">
        <Skeleton className="h-6 w-20" />
        <KpiCardsSkeleton count={4} />
        <ChartCardSkeleton />
        <TableSkeleton rows={5} cols={4} />
      </div>
    </div>
  );
}
