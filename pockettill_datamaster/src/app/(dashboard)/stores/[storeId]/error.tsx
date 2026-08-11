"use client";

import { SectionError } from "@/components/shared/section-error";

export default function StoreDetailError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Store"
      pageDescription="Store profile and activity."
      error={error}
      reset={reset}
    />
  );
}
