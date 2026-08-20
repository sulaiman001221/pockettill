import "server-only";
import { unstable_cache } from "next/cache";
import { createServiceRoleClient } from "@/lib/supabase/server";

/** Tag used to bust every cached read in this file after a store mutation. */
export const STORES_CACHE_TAG = "stores";

/** Business rule mirrored from the `is_founding_store()` Postgres function — keep in sync. */
export const FOUNDING_STORE_CAP = 100;

function startOfCurrentMonthIso() {
  const now = new Date();
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
}

export interface OverviewStats {
  activeStores: number;
  totalStores: number;
  newThisMonth: number;
  foundingStores: number;
  foundingCap: number;
  syncedLast24hCount: number;
  syncedLast24hPct: number;
  verifiedProducts: number;
  registeredUsers: number;
}

async function _getOverviewStats(): Promise<OverviewStats> {
  const supabase = createServiceRoleClient();
  const last24hIso = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const [
    { count: activeStores },
    { count: totalStores },
    { count: newThisMonth },
    { count: foundingStores },
    { count: syncedLast24hCount },
    { count: verifiedProducts },
  ] = await Promise.all([
    supabase.from("stores").select("*", { count: "exact", head: true }).eq("active", true),
    supabase.from("stores").select("*", { count: "exact", head: true }),
    supabase.from("stores").select("*", { count: "exact", head: true }).gte("created_at", startOfCurrentMonthIso()),
    supabase.from("stores").select("*", { count: "exact", head: true }).eq("is_beta_adopter", true),
    supabase.from("store_sync_status").select("*", { count: "exact", head: true }).gte("last_synced_at", last24hIso),
    // Verified products now live in their own table (catalogue_products) -
    // products.is_verified no longer exists after the catalogue split, so
    // counting verified products means counting rows here instead.
    supabase.from("catalogue_products").select("*", { count: "exact", head: true }),
  ]);

  const total = totalStores ?? 0;

  return {
    activeStores: activeStores ?? 0,
    totalStores: total,
    newThisMonth: newThisMonth ?? 0,
    foundingStores: foundingStores ?? 0,
    foundingCap: FOUNDING_STORE_CAP,
    syncedLast24hCount: syncedLast24hCount ?? 0,
    syncedLast24hPct: total > 0 ? Math.round(((syncedLast24hCount ?? 0) / total) * 100) : 0,
    verifiedProducts: verifiedProducts ?? 0,
    registeredUsers: total,
  };
}

export const getOverviewStats = unstable_cache(_getOverviewStats, ["overview-stats"], {
  tags: [STORES_CACHE_TAG],
  revalidate: 30,
});

export interface DailyRegistration {
  day: string;
  count: number;
}

async function _getDailyRegistrations(days = 30): Promise<DailyRegistration[]> {
  const supabase = createServiceRoleClient();
  const cutoff = new Date();
  cutoff.setUTCDate(cutoff.getUTCDate() - (days - 1));
  cutoff.setUTCHours(0, 0, 0, 0);

  const { data, error } = await supabase
    .from("stores")
    .select("created_at")
    .gte("created_at", cutoff.toISOString());

  if (error) throw new Error(error.message);

  const counts = new Map<string, number>();
  for (const row of data ?? []) {
    const key = row.created_at.slice(0, 10);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  const result: DailyRegistration[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(cutoff);
    d.setUTCDate(cutoff.getUTCDate() + (days - 1 - i));
    const key = d.toISOString().slice(0, 10);
    const label = d.toLocaleDateString("en-ZA", { month: "short", day: "numeric", timeZone: "UTC" });
    result.push({ day: label, count: counts.get(key) ?? 0 });
  }
  return result;
}

export const getDailyRegistrations = unstable_cache(_getDailyRegistrations, ["daily-registrations"], {
  tags: [STORES_CACHE_TAG],
  revalidate: 30,
});

export type StoreFilter = "all" | "active" | "inactive" | "founding";

export interface StoreListRow {
  id: string;
  name: string;
  phone: string;
  createdAt: string;
  isFounding: boolean;
  active: boolean;
  lastSyncedAt: string | null;
}

async function _getStoresList(params: {
  search?: string;
  filter?: StoreFilter;
} = {}): Promise<StoreListRow[]> {
  const supabase = createServiceRoleClient();

  let query = supabase
    .from("stores")
    .select("uuid, name, owner_phone, created_at, is_beta_adopter, active");

  const search = params.search?.trim().replace(/[(),]/g, "");
  if (search) {
    query = query.or(`name.ilike.%${search}%,owner_phone.ilike.%${search}%`);
  }

  if (params.filter === "active") query = query.eq("active", true);
  if (params.filter === "inactive") query = query.eq("active", false);
  if (params.filter === "founding") query = query.eq("is_beta_adopter", true);

  query = query.order("created_at", { ascending: false });

  const { data: stores, error } = await query;
  if (error) throw new Error(error.message);

  const storeIds = (stores ?? []).map((s) => s.uuid);
  const { data: syncRows } =
    storeIds.length > 0
      ? await supabase.from("store_sync_status").select("store_id, last_synced_at").in("store_id", storeIds)
      : { data: [] as { store_id: string; last_synced_at: string }[] };

  const syncMap = new Map((syncRows ?? []).map((r) => [r.store_id, r.last_synced_at]));

  return (stores ?? []).map((s) => ({
    id: s.uuid,
    name: s.name,
    phone: s.owner_phone,
    createdAt: s.created_at,
    isFounding: s.is_beta_adopter,
    active: s.active,
    lastSyncedAt: syncMap.get(s.uuid) ?? null,
  }));
}

export const getStoresList = unstable_cache(_getStoresList, ["stores-list"], {
  tags: [STORES_CACHE_TAG],
  revalidate: 30,
});

export interface StoreDetail {
  store: {
    id: string;
    name: string;
    phone: string;
    createdAt: string;
    active: boolean;
    isFounding: boolean;
  };
  syncHistory: {
    id: number;
    createdAt: string;
    eventsPushed: number;
    eventsPulled: number;
    deviceId: string;
  }[];
  sales: { count: number; totalRevenue: number };
  credit: { count: number; totalOutstanding: number };
  devices: { id: string; verifiedAt: string | null; lastSeenAt: string | null }[];
}

async function _getStoreDetail(storeId: string): Promise<StoreDetail | null> {
  const supabase = createServiceRoleClient();

  const [storeRes, syncRes, salesRes, creditRes, devicesRes] = await Promise.all([
    supabase
      .from("stores")
      .select("uuid, name, owner_phone, created_at, active, is_beta_adopter")
      .eq("uuid", storeId)
      .maybeSingle(),
    supabase
      .from("sync_log")
      .select("id, created_at, events_pushed, events_pulled, device_id")
      .eq("store_id", storeId)
      .order("created_at", { ascending: false })
      .limit(10),
    supabase.from("sales").select("total", { count: "exact" }).eq("store_id", storeId),
    supabase.from("credit_customers").select("balance", { count: "exact" }).eq("store_id", storeId),
    supabase.from("devices").select("id, verified_at, last_seen_at").eq("store_id", storeId),
  ]);

  if (storeRes.error) throw new Error(storeRes.error.message);
  if (!storeRes.data) return null;

  const totalRevenue = (salesRes.data ?? []).reduce((sum, s) => sum + Number(s.total), 0);
  const totalOutstanding = (creditRes.data ?? []).reduce((sum, c) => sum + Number(c.balance), 0);

  return {
    store: {
      id: storeRes.data.uuid,
      name: storeRes.data.name,
      phone: storeRes.data.owner_phone,
      createdAt: storeRes.data.created_at,
      active: storeRes.data.active,
      isFounding: storeRes.data.is_beta_adopter,
    },
    syncHistory: (syncRes.data ?? []).map((r) => ({
      id: r.id,
      createdAt: r.created_at,
      eventsPushed: r.events_pushed,
      eventsPulled: r.events_pulled,
      deviceId: r.device_id,
    })),
    sales: { count: salesRes.count ?? 0, totalRevenue },
    credit: { count: creditRes.count ?? 0, totalOutstanding },
    devices: (devicesRes.data ?? []).map((d) => ({
      id: d.id,
      verifiedAt: d.verified_at,
      lastSeenAt: d.last_seen_at,
    })),
  };
}

export const getStoreDetail = unstable_cache(_getStoreDetail, ["store-detail"], {
  tags: [STORES_CACHE_TAG],
  revalidate: 30,
});
