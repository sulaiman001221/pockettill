import { Settings } from "lucide-react";

import { ErrorLogFilters } from "@/components/error-logs/error-log-filters";
import { ErrorLogPagination } from "@/components/error-logs/error-log-pagination";
import { ErrorLogTable } from "@/components/error-logs/error-log-table";
import { InfraErrorBanner } from "@/components/shared/infra-error-banner";
import { PageHeader } from "@/components/shared/page-header";
import { PlaceholderPanel } from "@/components/shared/placeholder-panel";
import { getErrorLogs, type LogLevelFilter } from "@/lib/data/error-logs";

export const metadata = { title: "Error Logs" };

const PAGE_SIZE = 10;
const VALID_LEVELS: LogLevelFilter[] = ["all", "error", "warning"];

async function retry() {
  "use server";
  // Nothing to revalidate — getErrorLogs is deliberately uncached, so a
  // fresh page load already re-queries. This just gives the Retry button
  // something to await before router.refresh() re-renders the page.
}

export default async function ErrorLogsPage({
  searchParams,
}: {
  searchParams: { level?: string; page?: string };
}) {
  const level = VALID_LEVELS.includes(searchParams.level as LogLevelFilter)
    ? (searchParams.level as LogLevelFilter)
    : "all";
  const page = Math.max(1, Number(searchParams.page ?? "1") || 1);

  const result = await getErrorLogs({ level, page, pageSize: PAGE_SIZE });

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Error Logs"
        description="Postgres logs from every client — the mobile app included — for diagnosing real issues."
      />

      {result.status === "missing_config" ? (
        <PlaceholderPanel
          icon={Settings}
          title="Supabase Management API not connected"
          description="Add SUPABASE_MANAGEMENT_API_KEY and SUPABASE_PROJECT_REF to env vars."
        />
      ) : result.status === "error" ? (
        <InfraErrorBanner message={result.message} onRetry={retry} />
      ) : (
        <>
          <ErrorLogFilters level={level} />
          <ErrorLogTable entries={result.data.entries} />
          <ErrorLogPagination level={level} page={page} pageSize={PAGE_SIZE} total={result.data.total} />
        </>
      )}
    </div>
  );
}
