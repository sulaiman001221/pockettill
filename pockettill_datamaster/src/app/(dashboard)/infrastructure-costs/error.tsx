"use client";

import { SectionError } from "@/components/shared/section-error";

export default function InfrastructureCostsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Infrastructure Costs"
      pageDescription="Read-only usage and cost tracking for platform services."
      error={error}
      reset={reset}
    />
  );
}
