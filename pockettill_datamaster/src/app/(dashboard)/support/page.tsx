import { PageHeader } from "@/components/shared/page-header";
import { KpiCard } from "@/components/shared/kpi-card";
import { SupportQueriesTable } from "@/components/support/support-queries-table";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { getSupportQueries, getSupportStats } from "@/lib/data/support";
import { CheckCircle2, Clock, Inbox } from "lucide-react";

export const metadata = { title: "Support" };

export default async function SupportPage({
  searchParams,
}: {
  searchParams: { status?: string; q?: string };
}) {
  const status = searchParams.status ?? "";
  const search = searchParams.q ?? "";

  const [queries, stats, admin] = await Promise.all([
    getSupportQueries({ status, search }),
    getSupportStats(),
    getCurrentAdmin(),
  ]);

  const canManage = admin ? canManageStores(admin.role) : false;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Support"
        description="Enquiries submitted from the PocketTill website contact form."
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <KpiCard
          label="New"
          value={String(stats.newCount)}
          tone="blue"
          icon={<Inbox className="size-4.5" />}
        />
        <KpiCard
          label="In progress"
          value={String(stats.inProgressCount)}
          tone="amber"
          icon={<Clock className="size-4.5" />}
        />
        <KpiCard
          label="Resolved"
          value={String(stats.resolvedCount)}
          tone="emerald"
          icon={<CheckCircle2 className="size-4.5" />}
        />
      </div>

      <SupportQueriesTable
        queries={queries}
        status={status}
        search={search}
        canManage={canManage}
      />
    </div>
  );
}
