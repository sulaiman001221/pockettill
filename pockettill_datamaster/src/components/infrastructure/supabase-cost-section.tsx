import { Activity, AlertTriangle, Database, HardDrive, Layers, Settings } from "lucide-react";

import { KpiCard } from "@/components/shared/kpi-card";
import { PlaceholderPanel } from "@/components/shared/placeholder-panel";
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
    return (
      <div className="flex items-center gap-2 rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-600 dark:text-amber-400">
        <AlertTriangle className="size-4 shrink-0" />
        Supabase usage data is stale — the last request failed ({result.message}).
      </div>
    );
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
