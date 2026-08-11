"use client";

import { SectionError } from "@/components/shared/section-error";

export default function ProductCatalogueError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Product Catalogue"
      pageDescription="Cross-store catalogue, deduplicated by barcode."
      error={error}
      reset={reset}
    />
  );
}
