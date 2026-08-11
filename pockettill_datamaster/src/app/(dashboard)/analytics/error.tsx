"use client";

import { SectionError } from "@/components/shared/section-error";

export default function AnalyticsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Analytics"
      pageDescription="Aggregated platform-wide charts."
      error={error}
      reset={reset}
    />
  );
}
