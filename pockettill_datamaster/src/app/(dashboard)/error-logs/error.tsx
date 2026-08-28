"use client";

import { SectionError } from "@/components/shared/section-error";

export default function ErrorLogsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Error Logs"
      pageDescription="Postgres logs from every client — the mobile app included — for diagnosing real issues."
      error={error}
      reset={reset}
    />
  );
}
