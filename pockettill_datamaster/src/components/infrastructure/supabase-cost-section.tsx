import { Activity, Database, HardDrive, Layers, Settings } from "lucide-react";

import { InfraErrorBanner } from "@/components/shared/infra-error-banner";
import { KpiCard } from "@/components/shared/kpi-card";
import { PlaceholderPanel } from "@/components/shared/placeholder-panel";
import { retrySupabaseCosts } from "@/lib/actions/infrastructure";
import { getSupabaseCostData } from "@/lib/costs/supabase-usage";

function formatBytes(bytes: number | null) {
  if (bytes === null) return "—";
  const mb = bytes / (1024 * 1024);
  if (mb < 1024) return `${mb.toFixed(1)} MB`;
  return `${(mb / 1024).toFixed(2)} GB`;
}

export async function SupabaseCostSection() {
  const result = await getSupabaseCostData();

  if (result.status === "missing_config") {
    return (
      <PlaceholderPanel
        icon={Settings}
        title="Supabase Management API not connected"
        description="Add SUPABASE_MANAGEMENT_API_KEY to env vars."
      />
    );
  }

  if (result.status === "error") {
    return <InfraErrorBanner message={result.message} onRetry={retrySupabaseCosts} />;
  }

  const { data } = result;
  const dbSizeMb = data.dbSizeBytes ? data.dbSizeBytes / (1024 * 1024) : null;
  const overSoftLimit = dbSizeMb !== null && dbSizeMb > 400;

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <KpiCard label="Plan" value={data.plan} icon={<Layers className="size-4.5" />} tone="violet" />
      <KpiCard
        label="Database Size"
        value={formatBytes(data.dbSizeBytes)}
        hint={overSoftLimit ? "Over 400MB — approaching the 500MB free tier limit" : "Free tier limit: 500MB"}
        icon={<HardDrive className="size-4.5" />}
        tone="blue"
      />
      <KpiCard
        label="API Requests (Month)"
        value={data.apiRequestsThisMonth !== null ? String(data.apiRequestsThisMonth) : "—"}
        icon={<Activity className="size-4.5" />}
        tone="emerald"
      />
      <KpiCard
        label="Storage Used"
        value={formatBytes(data.storageSizeBytes)}
        icon={<Database className="size-4.5" />}
        tone="amber"
      />
    </div>
  );
}
