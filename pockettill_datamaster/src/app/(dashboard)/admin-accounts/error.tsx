"use client";

import { SectionError } from "@/components/shared/section-error";

export default function AdminAccountsError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <SectionError
      pageTitle="Admin Accounts"
      pageDescription="Invite teammates and manage roles."
      error={error}
      reset={reset}
    />
  );
}
