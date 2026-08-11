import "server-only";
import { unstable_cache } from "next/cache";
import { createServiceRoleClient } from "@/lib/supabase/server";

/** Not admin-mutated — reflects aggregate sales data written by the POS app. */
export const ANALYTICS_CACHE_TAG = "analytics";

const DAY_MS = 24 * 60 * 60 * 1000;

export interface DailySalesStat {
  day: string;
  activeStores: number;
  salesCount: number;
  revenue: number;
}

export interface CategoryQuantity {
  category: string;
  quantity: number;
}

export interface PaymentSplit {
  method: string;
  count: number;
}

function dayLabel(date: Date) {
  return date.toLocaleDateString("en-ZA", { month: "short", day: "numeric", timeZone: "UTC" });
}

async function _getSalesDailyStats(days: number): Promise<DailySalesStat[]> {
  const supabase = createServiceRoleClient();
  const now = Date.now();
  const cutoff = new Date(now - (days - 1) * DAY_MS).toISOString().slice(0, 10);

  const { data, error } = await supabase
    .from("sales_daily_stats")
    .select("day, active_stores, sales_count, revenue")
    .gte("day", cutoff);

  if (error) throw new Error(error.message);

  const map = new Map((data ?? []).map((r) => [r.day, r]));
  const result: DailySalesStat[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now - i * DAY_MS);
    const key = d.toISOString().slice(0, 10);
    const row = map.get(key);
    result.push({
      day: dayLabel(d),
      activeStores: row?.active_stores ?? 0,
      salesCount: row?.sales_count ?? 0,
      revenue: row ? Number(row.revenue) : 0,
    });
  }
  return result;
}

export const getSalesDailyStats = unstable_cache(_getSalesDailyStats, ["sales-daily-stats"], {
  tags: [ANALYTICS_CACHE_TAG],
  revalidate: 60,
});

async function _getCategorySalesStats(days: number): Promise<CategoryQuantity[]> {
  const supabase = createServiceRoleClient();
  const { data, error } = await supabase.rpc("category_sales_stats", { days });
  if (error) throw new Error(error.message);
  return (data ?? []).map((r: { category: string; total_quantity: number }) => ({
    category: r.category,
    quantity: Number(r.total_quantity),
  }));
}

export const getCategorySalesStats = unstable_cache(_getCategorySalesStats, ["category-sales-stats"], {
  tags: [ANALYTICS_CACHE_TAG],
  revalidate: 60,
});

async function _getPaymentMethodSplit(days: number): Promise<PaymentSplit[]> {
  const supabase = createServiceRoleClient();
  const cutoff = new Date(Date.now() - days * DAY_MS).toISOString();

  const { data, error } = await supabase.from("sales").select("payment_type").gte("created_at", cutoff);
  if (error) throw new Error(error.message);

  const counts = new Map<string, number>();
  for (const row of data ?? []) {
    const method = row.payment_type ?? "Unknown";
    counts.set(method, (counts.get(method) ?? 0) + 1);
  }

  return Array.from(counts.entries()).map(([method, count]) => ({ method, count }));
}

export const getPaymentMethodSplit = unstable_cache(_getPaymentMethodSplit, ["payment-method-split"], {
  tags: [ANALYTICS_CACHE_TAG],
  revalidate: 60,
});
