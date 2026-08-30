import "server-only";
import { unstable_cache } from "next/cache";
import { BetaAnalyticsDataClient } from "@google-analytics/data";
import { describeError } from "@/lib/errors";

// NOTE: built against the documented GA4 Data API (a mature, stable
// Google API), but never exercised against a real property — no
// credentials were available while building this. The one genuine
// uncertainty is whether `bounceRate` comes back as a percentage number
// (e.g. 45.3) or a fraction (0.453); we assume percentage. Test once real
// GA4_* env vars are set and adjust formatBounceRate in the UI if it's off
// by a factor of 100.

const DAY_MS = 24 * 60 * 60 * 1000;

export interface GA4Kpis {
  totalUsers: number;
  screenPageViews: number;
  bounceRatePct: number;
  avgSessionDurationSec: number;
}

export interface GA4DailyVisitors {
  day: string;
  totalUsers: number;
}

export interface GA4ChannelSplit {
  channel: string;
  sessions: number;
}

export interface GA4TopPage {
  path: string;
  views: number;
}

export interface GA4TopCountry {
  country: string;
  users: number;
}

export interface GA4Data {
  kpis: GA4Kpis;
  dailyVisitors: GA4DailyVisitors[];
  channelSplit: GA4ChannelSplit[];
  topPages: GA4TopPage[];
  topCountries: GA4TopCountry[];
}

export type GA4Result =
  | { status: "missing_config" }
  | { status: "error"; message: string }
  | { status: "ok"; data: GA4Data };

function dayLabel(yyyymmdd: string) {
  const y = yyyymmdd.slice(0, 4);
  const m = yyyymmdd.slice(4, 6);
  const d = yyyymmdd.slice(6, 8);
  return new Date(`${y}-${m}-${d}T00:00:00Z`).toLocaleDateString("en-ZA", {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  });
}

async function _getWebsiteTrafficData(days: number): Promise<GA4Result> {
  const propertyId = process.env.GA4_PROPERTY_ID;
  const clientEmail = process.env.GA4_CLIENT_EMAIL;
  const privateKey = process.env.GA4_PRIVATE_KEY;

  if (!propertyId || !clientEmail || !privateKey) {
    return { status: "missing_config" };
  }

  try {
    const client = new BetaAnalyticsDataClient({
      // The client library defaults to gRPC, which has well-documented
      // connectivity problems on serverless platforms like Vercel (requests
      // hang in gRPC's internal load-balancer subchannel-picking step and
      // eventually time out with DEADLINE_EXCEEDED, seen live in production).
      // Forcing REST transport avoids that class of failure entirely.
      fallback: true,
      credentials: {
        client_email: clientEmail,
        private_key: privateKey.replace(/\\n/g, "\n"),
      },
    });

    const dateRange = { startDate: `${days}daysAgo`, endDate: "today" };

    const [kpiRes, dailyRes, channelRes, pagesRes, countriesRes] = await Promise.all([
      client.runReport({
        property: propertyId,
        dateRanges: [dateRange],
        metrics: [
          { name: "totalUsers" },
          { name: "screenPageViews" },
          { name: "bounceRate" },
          { name: "averageSessionDuration" },
        ],
      }),
      client.runReport({
        property: propertyId,
        dateRanges: [dateRange],
        dimensions: [{ name: "date" }],
        metrics: [{ name: "totalUsers" }],
        orderBys: [{ dimension: { dimensionName: "date" } }],
      }),
      client.runReport({
        property: propertyId,
        dateRanges: [dateRange],
        dimensions: [{ name: "sessionDefaultChannelGroup" }],
        metrics: [{ name: "sessions" }],
        orderBys: [{ metric: { metricName: "sessions" }, desc: true }],
      }),
      client.runReport({
        property: propertyId,
        dateRanges: [dateRange],
        dimensions: [{ name: "pagePath" }],
        metrics: [{ name: "screenPageViews" }],
        orderBys: [{ metric: { metricName: "screenPageViews" }, desc: true }],
        limit: 10,
      }),
      client.runReport({
        property: propertyId,
        dateRanges: [dateRange],
        dimensions: [{ name: "country" }],
        metrics: [{ name: "totalUsers" }],
        orderBys: [{ metric: { metricName: "totalUsers" }, desc: true }],
        limit: 50,
      }),
    ]);

    const kpiRow = kpiRes[0].rows?.[0];
    const kpis: GA4Kpis = {
      totalUsers: Number(kpiRow?.metricValues?.[0]?.value ?? 0),
      screenPageViews: Number(kpiRow?.metricValues?.[1]?.value ?? 0),
      bounceRatePct: Number(kpiRow?.metricValues?.[2]?.value ?? 0),
      avgSessionDurationSec: Number(kpiRow?.metricValues?.[3]?.value ?? 0),
    };

    const dailyMap = new Map(
      (dailyRes[0].rows ?? []).map((r) => [
        r.dimensionValues?.[0]?.value ?? "",
        Number(r.metricValues?.[0]?.value ?? 0),
      ])
    );
    const dailyVisitors: GA4DailyVisitors[] = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(Date.now() - i * DAY_MS);
      const key = `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, "0")}${String(
        d.getUTCDate()
      ).padStart(2, "0")}`;
      dailyVisitors.push({ day: dayLabel(key), totalUsers: dailyMap.get(key) ?? 0 });
    }

    const channelSplit: GA4ChannelSplit[] = (channelRes[0].rows ?? []).map((r) => ({
      channel: r.dimensionValues?.[0]?.value ?? "Unknown",
      sessions: Number(r.metricValues?.[0]?.value ?? 0),
    }));

    const topPages: GA4TopPage[] = (pagesRes[0].rows ?? []).map((r) => ({
      path: r.dimensionValues?.[0]?.value ?? "",
      views: Number(r.metricValues?.[0]?.value ?? 0),
    }));

    const topCountries: GA4TopCountry[] = (countriesRes[0].rows ?? []).map((r) => ({
      country: r.dimensionValues?.[0]?.value ?? "Unknown",
      users: Number(r.metricValues?.[0]?.value ?? 0),
    }));

    return {
      status: "ok",
      data: { kpis, dailyVisitors, channelSplit, topPages, topCountries },
    };
  } catch (err) {
    console.error("[ga4-traffic]", err);
    return { status: "error", message: describeError(err) };
  }
}

/** External GA4 Data API call — traffic data doesn't need to be fresher than a few minutes. */
export const getWebsiteTrafficData = unstable_cache(_getWebsiteTrafficData, ["ga4-traffic-data"], {
  tags: ["ga4-traffic"],
  revalidate: 300,
});
