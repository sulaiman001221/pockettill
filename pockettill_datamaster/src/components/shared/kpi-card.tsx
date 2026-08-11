"use client";

import * as React from "react";
import { TrendingDown, TrendingUp } from "lucide-react";
import { Area, AreaChart, ResponsiveContainer } from "recharts";

import { Card, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export type KpiTone = "blue" | "emerald" | "amber" | "violet" | "rose" | "cyan";

const TONE_CLASSES: Record<KpiTone, string> = {
  blue: "bg-blue-500/15 text-blue-500",
  emerald: "bg-emerald-500/15 text-emerald-500",
  amber: "bg-amber-500/15 text-amber-500",
  violet: "bg-violet-500/15 text-violet-500",
  rose: "bg-rose-500/15 text-rose-500",
  cyan: "bg-cyan-500/15 text-cyan-500",
};

interface KpiCardProps {
  label: string;
  value: string;
  /** A rendered icon element, e.g. `icon={<Store className="size-4.5" />}`. */
  icon?: React.ReactNode;
  tone?: KpiTone;
  /** Legacy plain-text hint, shown when there's no trend/sparkline yet. */
  hint?: string;
  trend?: { value: number; direction: "up" | "down" };
  sparkline?: number[];
  className?: string;
}

export function KpiCard({
  label,
  value,
  icon,
  tone = "blue",
  hint,
  trend,
  sparkline,
  className,
}: KpiCardProps) {
  const gradientId = React.useId();
  const chartData = sparkline?.map((v, i) => ({ i, v }));

  return (
    <Card size="sm" className={className}>
      <CardContent className="flex flex-col gap-2.5">
        {icon || trend ? (
          <div className="flex items-center justify-between">
            {icon ? (
              <div
                className={cn(
                  "flex size-8 items-center justify-center rounded-lg",
                  TONE_CLASSES[tone]
                )}
              >
                {icon}
              </div>
            ) : (
              <span />
            )}
            {trend ? (
              <span
                className={cn(
                  "inline-flex items-center gap-0.5 rounded-full px-1.5 py-0.5 text-xs font-medium",
                  trend.direction === "up"
                    ? "bg-emerald-500/10 text-emerald-500"
                    : "bg-red-500/10 text-red-500"
                )}
              >
                {trend.direction === "up" ? (
                  <TrendingUp className="size-3" />
                ) : (
                  <TrendingDown className="size-3" />
                )}
                {trend.value}%
              </span>
            ) : null}
          </div>
        ) : null}

        <div className="flex flex-col gap-1">
          <span className="text-2xl font-semibold">{value}</span>
          <span className="text-sm text-muted-foreground">{label}</span>
        </div>

        {chartData ? (
          <div className="h-12 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 2, right: 0, bottom: 0, left: 0 }}>
                <defs>
                  <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--primary)" stopOpacity={0.35} />
                    <stop offset="100%" stopColor="var(--primary)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <Area
                  type="monotone"
                  dataKey="v"
                  stroke="var(--primary)"
                  strokeWidth={2}
                  fill={`url(#${gradientId})`}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        ) : hint ? (
          <p className="text-xs text-muted-foreground">{hint}</p>
        ) : null}
      </CardContent>
    </Card>
  );
}
