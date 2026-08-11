import { PageHeader } from "@/components/shared/page-header";
import { ChartCardSkeleton } from "@/components/shared/skeletons";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export default function SyncHealthLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Sync Health"
        description="Stores that haven't synced recently, and sync trends over time."
      />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        {Array.from({ length: 3 }).map((_, i) => (
          <Card key={`list-${i}`}>
            <CardHeader>
              <Skeleton className="h-5 w-24" />
            </CardHeader>
            <CardContent className="flex flex-col gap-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </CardContent>
          </Card>
        ))}
        {Array.from({ length: 3 }).map((_, i) => (
          <Card key={`kpi-${i}`}>
            <CardContent className="flex flex-col gap-4">
              <Skeleton className="size-9 rounded-lg" />
              <div className="flex flex-col gap-2">
                <Skeleton className="h-7 w-16" />
                <Skeleton className="h-4 w-24" />
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
      <ChartCardSkeleton />
    </div>
  );
}
