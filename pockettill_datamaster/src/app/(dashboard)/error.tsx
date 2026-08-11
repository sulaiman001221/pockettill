"use client";

import { SectionError } from "@/components/shared/section-error";

export default function OverviewError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Overview"
      pageDescription="Platform-wide KPIs and health at a glance."
      error={error}
      reset={reset}
    />
  );
}
