import "server-only";
import { unstable_cache } from "next/cache";
import { createServiceRoleClient } from "@/lib/supabase/server";

/** Not admin-mutated — reflects the mobile app's own sync activity. */
export const SYNC_HEALTH_CACHE_TAG = "sync-health";

const DAY_MS = 24 * 60 * 60 * 1000;

export type SyncSeverity = "critical" | "warning" | "nudge";

export interface SyncAlertStore {
  id: string;
  name: string;
  phone: string;
  lastSyncedAt: string | null;
  daysSinceSync: number | null;
}

export interface DailySyncPct {
  day: string;
  pct: number;
}

export interface SyncHealthData {
  critical: SyncAlertStore[];
  warning: SyncAlertStore[];
  nudge: SyncAlertStore[];
  neverSyncedCount: number;
  medianSyncGapHours: number | null;
  syncedLast24hCount: number;
  syncedLast24hPct: number;
  totalStores: number;
  dailyTrend: DailySyncPct[];
}

function sortStaleFirst(a: SyncAlertStore, b: SyncAlertStore) {
  if (a.daysSinceSync === null) return -1;
  if (b.daysSinceSync === null) return 1;
  return b.daysSinceSync - a.daysSinceSync;
}

/** % of stores that synced each day, over the last `days` days. Backs Sync Health's own trend and Analytics' "Sync Health Over Time" chart. */
async function _getSyncTrend(days: number): Promise<DailySyncPct[]> {
  const supabase = createServiceRoleClient();
  const now = Date.now();
  const cutoff = new Date(now - (days - 1) * DAY_MS).toISOString().slice(0, 10);

  const [{ count: totalStores }, dailyRes] = await Promise.all([
    supabase.from("stores").select("*", { count: "exact", head: true }),
    supabase.from("sync_daily_active_stores").select("day, active_stores").gte("day", cutoff),
  ]);

  const total = totalStores ?? 0;
  const dailyMap = new Map((dailyRes.data ?? []).map((r) => [r.day, r.active_stores]));
  const trend: DailySyncPct[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now - i * DAY_MS);
    const key = d.toISOString().slice(0, 10);
    const label = d.toLocaleDateString("en-ZA", { month: "short", day: "numeric", timeZone: "UTC" });
    const active = dailyMap.get(key) ?? 0;
    trend.push({ day: label, pct: total > 0 ? Math.round((active / total) * 100) : 0 });
  }
  return trend;
}

export const getSyncTrend = unstable_cache(_getSyncTrend, ["sync-trend"], {
  tags: [SYNC_HEALTH_CACHE_TAG],
  revalidate: 60,
});

async function _getSyncHealthData(): Promise<SyncHealthData> {
  const supabase = createServiceRoleClient();
  const now = Date.now();

  const [storesRes, syncStatusRes, medianRes, dailyTrend] = await Promise.all([
    supabase.from("stores").select("uuid, name, owner_phone"),
    supabase.from("store_sync_status").select("store_id, last_synced_at"),
    supabase.rpc("median_sync_gap_hours"),
    getSyncTrend(30),
  ]);

  if (storesRes.error) throw new Error(storesRes.error.message);

  const stores = storesRes.data ?? [];
  const syncStatus = syncStatusRes.data ?? [];
  const syncMap = new Map(syncStatus.map((r) => [r.store_id, r.last_synced_at]));
  const totalStores = stores.length;

  const critical: SyncAlertStore[] = [];
  const warning: SyncAlertStore[] = [];
  const nudge: SyncAlertStore[] = [];

  for (const store of stores) {
    const lastSyncedAt = syncMap.get(store.uuid) ?? null;
    const daysSinceSync = lastSyncedAt
      ? Math.floor((now - new Date(lastSyncedAt).getTime()) / DAY_MS)
      : null;

    const entry: SyncAlertStore = {
      id: store.uuid,
      name: store.name,
      phone: store.owner_phone,
      lastSyncedAt,
      daysSinceSync,
    };

    if (daysSinceSync === null || daysSinceSync >= 30) {
      critical.push(entry);
    } else if (daysSinceSync >= 7) {
      warning.push(entry);
    } else if (daysSinceSync >= 3) {
      nudge.push(entry);
    }
  }

  critical.sort(sortStaleFirst);
  warning.sort(sortStaleFirst);
  nudge.sort(sortStaleFirst);

  const neverSyncedCount = totalStores - syncStatus.length;

  const last24hCutoff = now - DAY_MS;
  const syncedLast24hCount = syncStatus.filter(
    (r) => new Date(r.last_synced_at).getTime() >= last24hCutoff
  ).length;
  const syncedLast24hPct = totalStores > 0 ? Math.round((syncedLast24hCount / totalStores) * 100) : 0;

  const medianSyncGapHours =
    medianRes.data !== null && medianRes.data !== undefined ? Number(medianRes.data) : null;

  return {
    critical,
    warning,
    nudge,
    neverSyncedCount,
    medianSyncGapHours,
    syncedLast24hCount,
    syncedLast24hPct,
    totalStores,
    dailyTrend,
  };
}

export const getSyncHealthData = unstable_cache(_getSyncHealthData, ["sync-health-data"], {
  tags: [SYNC_HEALTH_CACHE_TAG],
  revalidate: 60,
});
