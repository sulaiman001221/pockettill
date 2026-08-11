"use client";

import { usePathname, useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";

const RANGES = [
  { value: "7", label: "Last 7 days" },
  { value: "30", label: "Last 30 days" },
  { value: "90", label: "Last 90 days" },
];

export function DateRangeSelector({ value }: { value: string }) {
  const router = useRouter();
  const pathname = usePathname();

  return (
    <div className="flex flex-wrap gap-2">
      {RANGES.map((r) => (
        <Button
          key={r.value}
          size="sm"
          variant={value === r.value ? "default" : "outline"}
          onClick={() => router.push(`${pathname}?range=${r.value}`)}
        >
          {r.label}
        </Button>
      ))}
    </div>
  );
}
