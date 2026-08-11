"use client";

import { SectionError } from "@/components/shared/section-error";

export default function WebsiteTrafficError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Website Traffic"
      pageDescription="Marketing site traffic via GA4."
      error={error}
      reset={reset}
    />
  );
}
