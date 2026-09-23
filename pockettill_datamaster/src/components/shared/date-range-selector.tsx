"use client";

import { useEffect, useState, useTransition } from "react";
import { usePathname, useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const RANGES = [
  { value: "7", label: "Last 7 days" },
  { value: "30", label: "Last 30 days" },
  { value: "90", label: "Last 90 days" },
];

export function DateRangeSelector({ value }: { value: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const [pending, startTransition] = useTransition();
  // Same fix as ErrorLogFilters: the highlighted button used to depend
  // entirely on the server round-trip (re-querying Supabase) completing, so
  // a click looked like it needed a second try before anything happened.
  // Track the clicked value locally so it highlights instantly - found
  // 2026-09-23, same underlying bug on this component and StoresFilters,
  // just never ported over when ErrorLogFilters first got this fix.
  const [optimisticValue, setOptimisticValue] = useState(value);

  useEffect(() => setOptimisticValue(value), [value]);

  function handleClick(next: string) {
    setOptimisticValue(next);
    startTransition(() => {
      router.push(`${pathname}?range=${next}`, { scroll: false });
    });
  }

  return (
    <div className="flex flex-wrap gap-2">
      {RANGES.map((r) => (
        <Button
          key={r.value}
          size="sm"
          variant={optimisticValue === r.value ? "default" : "outline"}
          className={cn(pending && optimisticValue === r.value && "opacity-70")}
          onClick={() => handleClick(r.value)}
        >
          {r.label}
        </Button>
      ))}
    </div>
  );
}
