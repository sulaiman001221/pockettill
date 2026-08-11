import { PageHeader } from "@/components/shared/page-header";
import { TableSkeleton } from "@/components/shared/skeletons";
import { Skeleton } from "@/components/ui/skeleton";

export default function AdminAccountsLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Admin Accounts"
        description="Invite teammates and manage roles."
        actions={<Skeleton className="h-9 w-32" />}
      />
      <TableSkeleton rows={5} cols={6} />
      <div className="flex flex-col gap-4">
        <Skeleton className="h-6 w-24" />
        <TableSkeleton rows={5} cols={4} />
      </div>
    </div>
  );
}
