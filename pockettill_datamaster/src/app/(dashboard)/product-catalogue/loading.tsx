import { PageHeader } from "@/components/shared/page-header";
import { ChartCardSkeleton, KpiCardsSkeleton, TableSkeleton } from "@/components/shared/skeletons";
import { Skeleton } from "@/components/ui/skeleton";

export default function ProductCatalogueLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Product Catalogue" description="Cross-store catalogue, deduplicated by barcode." />
      <div className="flex gap-2">
        <Skeleton className="h-9 w-40" />
        <Skeleton className="h-9 w-32" />
      </div>
      <KpiCardsSkeleton count={2} />
      <ChartCardSkeleton height="h-48" />
      <div className="flex gap-2">
        <Skeleton className="h-9 w-full max-w-sm" />
        <Skeleton className="h-9 w-48" />
      </div>
      <TableSkeleton rows={8} cols={5} />
    </div>
  );
}
