"use client";

import { SectionError } from "@/components/shared/section-error";

export default function SettingsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Settings"
      pageDescription="Manage your admin profile and appearance."
      error={error}
      reset={reset}
    />
  );
}
