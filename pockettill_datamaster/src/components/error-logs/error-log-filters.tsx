"use client";

import { usePathname, useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import type { LogLevelFilter } from "@/lib/data/error-logs";

const LEVELS: { value: LogLevelFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "error", label: "Error only" },
  { value: "warning", label: "Warning" },
];

export function ErrorLogFilters({ level }: { level: LogLevelFilter }) {
  const router = useRouter();
  const pathname = usePathname();

  return (
    <div className="flex flex-wrap gap-2">
      {LEVELS.map((l) => (
        <Button
          key={l.value}
          size="sm"
          variant={level === l.value ? "default" : "outline"}
          onClick={() => router.push(`${pathname}?level=${l.value}`, { scroll: false })}
        >
          {l.label}
        </Button>
      ))}
    </div>
  );
}
