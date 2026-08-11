import { AlertTriangle, CheckCircle2, DollarSign, MessageSquare, PieChart, Settings } from "lucide-react";

import { OtpLogTable } from "@/components/infrastructure/otp-log-table";
import { TwilioSpendChart } from "@/components/infrastructure/twilio-spend-chart";
import { DonutChart } from "@/components/shared/donut-chart";
import { KpiCard } from "@/components/shared/kpi-card";
import { PlaceholderPanel } from "@/components/shared/placeholder-panel";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { getTwilioCostData } from "@/lib/costs/twilio";

export async function TwilioSection() {
  const result = await getTwilioCostData();

  if (result.status === "missing_config") {
    return (
      <PlaceholderPanel
        icon={Settings}
        title="Twilio not connected"
        description="Add TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_VERIFY_SID to env vars."
      />
    );
  }

  if (result.status === "error") {
    return (
      <div className="flex items-center gap-2 rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-600 dark:text-amber-400">
        <AlertTriangle className="size-4 shrink-0" />
        Twilio data is stale — the last request failed ({result.message}).
      </div>
    );
  }

  const { data } = result;

  return (
    <div className="flex flex-col gap-4">
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard
          label="Current Balance"
          value={`$${data.balance.toFixed(2)}`}
          hint={data.currency}
          icon={<DollarSign className="size-4.5" />}
          tone="emerald"
        />
        <KpiCard
          label="OTPs Sent (Month)"
          value={String(data.otpsSentThisMonth)}
          icon={<MessageSquare className="size-4.5" />}
          tone="blue"
        />
        <KpiCard
          label="Success Rate"
          value={`${data.successRatePct}%`}
          icon={<CheckCircle2 className="size-4.5" />}
          tone="cyan"
        />
        <Card size="sm">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-1.5 text-sm font-medium text-muted-foreground">
              <PieChart className="size-4" />
              Channel Split
            </CardTitle>
          </CardHeader>
          <CardContent>
            {data.channelSplit.length > 0 ? (
              <DonutChart data={data.channelSplit.map((c) => ({ label: c.channel, value: c.count }))} />
            ) : (
              <p className="text-sm text-muted-foreground">No OTPs sent yet.</p>
            )}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Daily Spend</CardTitle>
          <CardDescription>Last 30 days.</CardDescription>
        </CardHeader>
        <CardContent>
          {data.dailySpend.length > 0 ? (
            <TwilioSpendChart data={data.dailySpend} />
          ) : (
            <p className="text-sm text-muted-foreground">No spend data available.</p>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Recent OTP Log</CardTitle>
        </CardHeader>
        <CardContent className="px-0">
          <OtpLogTable entries={data.recentLog} />
        </CardContent>
      </Card>
    </div>
  );
}
