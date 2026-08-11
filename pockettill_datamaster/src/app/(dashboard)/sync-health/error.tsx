"use client";

import { SectionError } from "@/components/shared/section-error";

export default function SyncHealthError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Sync Health"
      pageDescription="Stores that haven't synced recently, and sync trends over time."
      error={error}
      reset={reset}
    />
  );
}
