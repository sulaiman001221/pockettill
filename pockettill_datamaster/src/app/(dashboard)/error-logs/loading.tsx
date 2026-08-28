import { PageHeader } from "@/components/shared/page-header";
import { TableSkeleton } from "@/components/shared/skeletons";
import { Skeleton } from "@/components/ui/skeleton";

export default function ErrorLogsLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Error Logs"
        description="Postgres logs from every client — the mobile app included — for diagnosing real issues."
      />
      <div className="flex gap-2">
        <Skeleton className="h-9 w-16" />
        <Skeleton className="h-9 w-28" />
        <Skeleton className="h-9 w-28" />
      </div>
      <TableSkeleton rows={8} cols={4} />
    </div>
  );
}
