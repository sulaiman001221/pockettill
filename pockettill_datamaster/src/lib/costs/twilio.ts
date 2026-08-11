import "server-only";
import { unstable_cache } from "next/cache";

// Verified 2026-08-10 against a real Twilio account.
//
// Twilio has NO "verify" Usage Records category — `Category=verify` returns
// a 400 ("verify is not a valid choice"). Verify's OTP cost is billed
// through the underlying channel instead. Confirmed categories with real
// usage on this account: `sms` (rollup) and `sms-outbound-longcode` (its
// exact sub-category — same count/price, so summing both would double the
// real spend), plus `channels-whatsapp` / `channels-whatsapp-template-service`
// for WhatsApp. SPEND_CATEGORIES below sums the rollup categories only, so
// this is an approximation of "OTP spend" (it can't be perfectly isolated
// from any other SMS/WhatsApp traffic on the same Twilio account) rather
// than an exact Verify-only figure.
const SPEND_CATEGORIES = ["sms", "channels-whatsapp", "channels-whatsapp-template-service"];

const DAY_MS = 24 * 60 * 60 * 1000;

export interface TwilioOtpLogEntry {
  phone: string;
  channel: string;
  status: string;
  date: string;
}

export interface TwilioDailySpend {
  day: string;
  amount: number;
}

export interface TwilioCostData {
  balance: number;
  currency: string;
  otpsSentThisMonth: number;
  successRatePct: number;
  channelSplit: { channel: string; count: number }[];
  dailySpend: TwilioDailySpend[];
  recentLog: TwilioOtpLogEntry[];
}

export type TwilioCostResult =
  | { status: "missing_config" }
  | { status: "error"; message: string }
  | { status: "ok"; data: TwilioCostData };

function extractPhone(attempt: Record<string, unknown>): string {
  const channelData = attempt.channel_data as Record<string, unknown> | undefined;
  if (!channelData) return "";
  if (typeof channelData.to === "string") return channelData.to;
  const channel = attempt.channel as string | undefined;
  const nested = channel ? (channelData[channel] as Record<string, unknown> | undefined) : undefined;
  if (nested && typeof nested.to === "string") return nested.to;
  return "";
}

async function _getTwilioCostData(): Promise<TwilioCostResult> {
  const accountSid = process.env.TWILIO_ACCOUNT_SID;
  const authToken = process.env.TWILIO_AUTH_TOKEN;
  const verifySid = process.env.TWILIO_VERIFY_SID;

  if (!accountSid || !authToken || !verifySid) {
    return { status: "missing_config" };
  }

  const authHeader = "Basic " + Buffer.from(`${accountSid}:${authToken}`).toString("base64");

  try {
    const startOfMonth = new Date();
    startOfMonth.setUTCDate(1);
    startOfMonth.setUTCHours(0, 0, 0, 0);
    const usageStart = new Date(Date.now() - 29 * DAY_MS).toISOString().slice(0, 10);
    const usageEnd = new Date().toISOString().slice(0, 10);

    const [balanceRes, attemptsRes, ...usageResults] = await Promise.all([
      fetch(`https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Balance.json`, {
        headers: { Authorization: authHeader },
        cache: "no-store",
      }),
      fetch(
        `https://verify.twilio.com/v2/Attempts?VerifyServiceSid=${verifySid}&DateCreatedAfter=${startOfMonth.toISOString()}&PageSize=1000`,
        { headers: { Authorization: authHeader }, cache: "no-store" }
      ),
      ...SPEND_CATEGORIES.map((category) =>
        fetch(
          `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Usage/Records/Daily.json?Category=${category}&StartDate=${usageStart}&EndDate=${usageEnd}&PageSize=30`,
          { headers: { Authorization: authHeader }, cache: "no-store" }
        )
      ),
    ]);

    if (!balanceRes.ok) {
      return { status: "error", message: `Twilio Balance API returned ${balanceRes.status}.` };
    }
    if (!attemptsRes.ok) {
      return { status: "error", message: `Twilio Verify Attempts API returned ${attemptsRes.status}.` };
    }

    const balanceJson = await balanceRes.json();
    const attemptsJson = await attemptsRes.json();
    const attempts: Record<string, unknown>[] = attemptsJson.attempts ?? [];

    const converted = attempts.filter((a) => a.conversion_status === "converted").length;
    const successRatePct = attempts.length > 0 ? Math.round((converted / attempts.length) * 100) : 0;

    const channelCounts = new Map<string, number>();
    for (const a of attempts) {
      const ch = (a.channel as string) ?? "unknown";
      channelCounts.set(ch, (channelCounts.get(ch) ?? 0) + 1);
    }
    const channelSplit = Array.from(channelCounts.entries()).map(([channel, count]) => ({ channel, count }));

    const recentLog: TwilioOtpLogEntry[] = attempts.slice(0, 20).map((a) => ({
      phone: extractPhone(a),
      channel: (a.channel as string) ?? "unknown",
      status: (a.conversion_status as string) ?? "unknown",
      date: a.date_created as string,
    }));

    const spendByDay = new Map<string, number>();
    for (const res of usageResults) {
      if (!res.ok) continue;
      const json = await res.json();
      const records: Record<string, unknown>[] = json.usage_records ?? [];
      for (const r of records) {
        const key = r.start_date as string;
        spendByDay.set(key, (spendByDay.get(key) ?? 0) + Math.abs(Number(r.price ?? 0)));
      }
    }
    const dailySpend: TwilioDailySpend[] = Array.from(spendByDay.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, amount]) => ({
        day: new Date(date).toLocaleDateString("en-ZA", { month: "short", day: "numeric" }),
        amount,
      }));

    return {
      status: "ok",
      data: {
        balance: Number(balanceJson.balance ?? 0),
        currency: balanceJson.currency ?? "USD",
        otpsSentThisMonth: attempts.length,
        successRatePct,
        channelSplit,
        dailySpend,
        recentLog,
      },
    };
  } catch (err) {
    return { status: "error", message: err instanceof Error ? err.message : "Unknown error" };
  }
}

/** External Twilio API call — not affected by any admin mutation, safe to cache for a few minutes. */
export const getTwilioCostData = unstable_cache(_getTwilioCostData, ["twilio-cost-data"], {
  tags: ["twilio-costs"],
  revalidate: 180,
});
