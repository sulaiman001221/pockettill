import { PageHeader } from "@/components/shared/page-header";
import { TableSkeleton } from "@/components/shared/skeletons";
import { Skeleton } from "@/components/ui/skeleton";

export default function StoresLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Users" description="Search, filter, and drill into individual store accounts." />
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <Skeleton className="h-9 max-w-sm flex-1" />
        <div className="flex gap-2">
          <Skeleton className="h-8 w-16" />
          <Skeleton className="h-8 w-16" />
          <Skeleton className="h-8 w-20" />
          <Skeleton className="h-8 w-32" />
        </div>
      </div>
      <TableSkeleton rows={8} cols={6} />
    </div>
  );
}
