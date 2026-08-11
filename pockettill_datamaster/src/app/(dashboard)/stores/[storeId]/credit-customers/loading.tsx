import { PageHeader } from "@/components/shared/page-header";
import { TableSkeleton } from "@/components/shared/skeletons";
import { Skeleton } from "@/components/ui/skeleton";

export default function CreditCustomersLoading() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Credit Customers" description="Customers with store credit." />
      <Skeleton className="h-9 max-w-sm" />
      <TableSkeleton rows={6} cols={6} />
    </div>
  );
}
