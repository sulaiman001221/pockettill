import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Terms of Service",
  description: "PocketTill's terms of service — coming soon.",
};

export default function TermsPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-white px-6 text-center">
      <h1 className="text-3xl font-extrabold text-ink">
        Terms of Service
      </h1>
      <p className="mt-4 text-ink/60">Coming soon.</p>
      <Link
        href="/"
        className="mt-8 rounded-full bg-brand px-6 py-3 font-semibold text-white transition hover:bg-brand-dark"
      >
        Back to home
      </Link>
    </main>
  );
}
