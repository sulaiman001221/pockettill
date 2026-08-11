"use client";

import { useEffect } from "react";

import { ErrorCard } from "@/components/shared/error-card";
import { PageHeader } from "@/components/shared/page-header";

interface SectionErrorProps {
  pageTitle: string;
  pageDescription?: string;
  error: Error & { digest?: string };
  reset: () => void;
}

export function SectionError({ pageTitle, pageDescription, error, reset }: SectionErrorProps) {
  useEffect(() => {
    console.error(`[${pageTitle}]`, error);
  }, [pageTitle, error]);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title={pageTitle} description={pageDescription} />
      <ErrorCard onRetry={reset} />
    </div>
  );
}
