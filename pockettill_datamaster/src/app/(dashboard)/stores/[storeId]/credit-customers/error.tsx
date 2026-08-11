"use client";

import { SectionError } from "@/components/shared/section-error";

export default function CreditCustomersError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Credit Customers"
      pageDescription="Customers with store credit at this store."
      error={error}
      reset={reset}
    />
  );
}
