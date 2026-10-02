import "server-only";
import { unstable_cache } from "next/cache";

import { describeError } from "@/lib/errors";
import { estimateImageCostUsd } from "@/lib/gemini-image";
import { createServiceRoleClient } from "@/lib/supabase/server";

// Google exposes no spend/usage data through a Gemini API key (an API key only
// authorises model calls; actual billing lives in Google Cloud Billing, which
// needs a billing-export + service-account setup to read programmatically).
// So this is an ESTIMATE built from DataMaster's own record of its calls: every
// successful "Enhance with AI" writes an audit_log row carrying the model and
// the price per image at that moment (see enhanceImageWithAI). Google's actual
// invoice is the source of truth; this tracks it closely because image pricing
// is a flat per-image rate.

const ACTION = "product.image_enhanced_ai";
const DAY_MS = 24 * 60 * 60 * 1000;

export interface GeminiDailySpend {
  day: string;
  amount: number;
}

export interface GeminiCostData {
  enhancementsThisMonth: number;
  estimatedSpendThisMonthUsd: number;
  estimatedSpendLast30DaysUsd: number;
  avgCostPerImageUsd: number;
  lastEnhancedAt: string | null;
  dailySpend: GeminiDailySpend[];
}

export type GeminiCostResult =
  | { status: "missing_config" }
  | { status: "error"; message: string }
  | { status: "ok"; data: GeminiCostData };

function rowCostUsd(metadata: unknown): number {
  const m = (metadata ?? {}) as { cost_usd?: unknown; model?: unknown };
  if (typeof m.cost_usd === "number") return m.cost_usd;
  return estimateImageCostUsd(typeof m.model === "string" ? m.model : "");
}

async function _getGeminiCostData(): Promise<GeminiCostResult> {
  if (!process.env.GEMINI_API_KEY) return { status: "missing_config" };

  try {
    const supabase = createServiceRoleClient();
    const since = new Date(Date.now() - 29 * DAY_MS);
    since.setUTCHours(0, 0, 0, 0);

    const { data, error } = await supabase
      .from("audit_log")
      .select("metadata, created_at")
      .eq("action", ACTION)
      .gte("created_at", since.toISOString())
      .order("created_at", { ascending: true })
      .limit(10_000);
    if (error) return { status: "error", message: error.message };

    const startOfMonth = new Date();
    startOfMonth.setUTCDate(1);
    startOfMonth.setUTCHours(0, 0, 0, 0);

    let monthCount = 0;
    let monthSpend = 0;
    let last30Spend = 0;
    let last30Count = 0;
    let lastEnhancedAt: string | null = null;
    const byDay = new Map<string, number>();

    for (const row of data ?? []) {
      const cost = rowCostUsd(row.metadata);
      const when = new Date(row.created_at as string);
      last30Spend += cost;
      last30Count += 1;
      lastEnhancedAt = row.created_at as string;
      if (when >= startOfMonth) {
        monthCount += 1;
        monthSpend += cost;
      }
      const key = when.toISOString().slice(0, 10);
      byDay.set(key, (byDay.get(key) ?? 0) + cost);
    }

    // One point per calendar day for the last 30, zero-filled, so the chart's
    // x-axis is continuous instead of only showing days something happened.
    const dailySpend: GeminiDailySpend[] = [];
    for (let i = 29; i >= 0; i--) {
      const d = new Date(Date.now() - i * DAY_MS);
      dailySpend.push({
        day: d.toLocaleDateString("en-ZA", { month: "short", day: "numeric" }),
        amount: Math.round((byDay.get(d.toISOString().slice(0, 10)) ?? 0) * 10_000) / 10_000,
      });
    }

    return {
      status: "ok",
      data: {
        enhancementsThisMonth: monthCount,
        estimatedSpendThisMonthUsd: monthSpend,
        estimatedSpendLast30DaysUsd: last30Spend,
        avgCostPerImageUsd: last30Count > 0 ? last30Spend / last30Count : 0,
        lastEnhancedAt,
        dailySpend,
      },
    };
  } catch (err) {
    console.error("[gemini-costs]", err);
    return { status: "error", message: describeError(err) };
  }
}

/** Reads our own audit log, so a short cache is plenty - and it's refreshed
 * straight away by the Retry button (tag "gemini-costs"). */
export const getGeminiCostData = unstable_cache(_getGeminiCostData, ["gemini-cost-data"], {
  tags: ["gemini-costs"],
  revalidate: 60,
});
