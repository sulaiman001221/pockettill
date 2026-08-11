import { PageHeader } from "@/components/shared/page-header";
import { KpiCardsSkeleton, TableSkeleton } from "@/components/shared/skeletons";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export default function StoreDetailLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Store detail" description="Store profile and activity." />
      <Card>
        <CardContent className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="flex flex-col gap-2">
              <Skeleton className="h-4 w-16" />
              <Skeleton className="h-5 w-24" />
            </div>
          ))}
        </CardContent>
      </Card>
      <KpiCardsSkeleton count={6} />
      <TableSkeleton rows={5} cols={4} />
      <TableSkeleton rows={5} cols={3} />
    </div>
  );
}
