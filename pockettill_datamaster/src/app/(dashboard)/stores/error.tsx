"use client";

import { SectionError } from "@/components/shared/section-error";

export default function StoresError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Users"
      pageDescription="Search, filter, and drill into individual store accounts."
      error={error}
      reset={reset}
    />
  );
}
