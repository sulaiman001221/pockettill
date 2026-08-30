"use client";

import { useEffect, useState, useTransition } from "react";
import { usePathname, useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { LogLevelFilter } from "@/lib/data/error-logs";

const LEVELS: { value: LogLevelFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "error", label: "Error only" },
  { value: "warning", label: "Warning" },
];

export function ErrorLogFilters({ level }: { level: LogLevelFilter }) {
  const router = useRouter();
  const pathname = usePathname();
  const [pending, startTransition] = useTransition();
  // The active-button highlight otherwise depends entirely on the server
  // round-trip (re-querying Supabase's logs endpoint, which can be slow or
  // outright flaky) completing before it updates — clicking felt like it
  // needed a second try because nothing visibly happened on the first one.
  // Track the clicked value locally so it highlights instantly.
  const [optimisticLevel, setOptimisticLevel] = useState(level);

  useEffect(() => setOptimisticLevel(level), [level]);

  function handleClick(value: LogLevelFilter) {
    setOptimisticLevel(value);
    startTransition(() => {
      router.push(`${pathname}?level=${value}`, { scroll: false });
    });
  }

  return (
    <div className="flex flex-wrap gap-2">
      {LEVELS.map((l) => (
        <Button
          key={l.value}
          size="sm"
          variant={optimisticLevel === l.value ? "default" : "outline"}
          className={cn(pending && optimisticLevel === l.value && "opacity-70")}
          onClick={() => handleClick(l.value)}
        >
          {l.label}
        </Button>
      ))}
    </div>
  );
}
