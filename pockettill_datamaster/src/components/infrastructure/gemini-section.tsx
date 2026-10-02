import { Clock, DollarSign, ImagePlus, Settings, TrendingUp } from "lucide-react";

import { TwilioSpendChart } from "@/components/infrastructure/twilio-spend-chart";
import { InfraErrorBanner } from "@/components/shared/infra-error-banner";
import { KpiCard } from "@/components/shared/kpi-card";
import { PlaceholderPanel } from "@/components/shared/placeholder-panel";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { retryGeminiCosts } from "@/lib/actions/infrastructure";
import { getGeminiCostData } from "@/lib/costs/gemini";

/** Cents matter at this scale - $0.0336 per image would round to "$0.03" at two
 * decimals and a $0.07 month would read as "$0.10". */
function usd(amount: number): string {
  return amount < 1 ? `$${amount.toFixed(3)}` : `$${amount.toFixed(2)}`;
}

export async function GeminiSection() {
  const result = await getGeminiCostData();

  if (result.status === "missing_config") {
    return (
      <PlaceholderPanel
        icon={Settings}
        title="Gemini not connected"
        description="Add GEMINI_API_KEY to env vars to enable AI image enhancement and cost tracking."
      />
    );
  }

  if (result.status === "error") {
    return <InfraErrorBanner message={result.message} onRetry={retryGeminiCosts} />;
  }

  const { data } = result;

  return (
    <div className="flex flex-col gap-4">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          label="Est. Spend (Month)"
          value={usd(data.estimatedSpendThisMonthUsd)}
          hint="USD, estimated"
          icon={<DollarSign className="size-4.5" />}
          tone="emerald"
        />
        <KpiCard
          label="Images Enhanced (Month)"
          value={String(data.enhancementsThisMonth)}
          icon={<ImagePlus className="size-4.5" />}
          tone="blue"
        />
        <KpiCard
          label="Avg Cost / Image"
          value={data.avgCostPerImageUsd > 0 ? usd(data.avgCostPerImageUsd) : "—"}
          hint="Last 30 days"
          icon={<TrendingUp className="size-4.5" />}
          tone="cyan"
        />
        <KpiCard
          label="Last Enhancement"
          value={
            data.lastEnhancedAt
              ? new Date(data.lastEnhancedAt).toLocaleDateString("en-ZA", {
                  month: "short",
                  day: "numeric",
                })
              : "—"
          }
          icon={<Clock className="size-4.5" />}
          tone="violet"
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Daily Spend</CardTitle>
          <CardDescription>
            Last 30 days. Estimated from PocketTill&apos;s own record of each &quot;Enhance with
            AI&quot; click × Google&apos;s per-image price - Google doesn&apos;t share spend through an
            API key, so check Google AI Studio or Cloud Billing for the exact invoice.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <TwilioSpendChart data={data.dailySpend} />
        </CardContent>
      </Card>
    </div>
  );
}
