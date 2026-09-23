"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState, useTransition } from "react";
import { Search } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import type { StoreFilter } from "@/lib/data/stores";

const FILTERS: { value: StoreFilter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "active", label: "Active" },
  { value: "inactive", label: "Inactive" },
  { value: "founding", label: "Founding stores" },
];

export function StoresFilters({ search, filter }: { search: string; filter: StoreFilter }) {
  const router = useRouter();
  const pathname = usePathname();
  const [value, setValue] = useState(search);
  const [pending, startTransition] = useTransition();
  // The filter chip's highlight used to depend entirely on the server
  // round-trip (re-querying Supabase for the new page of stores) completing
  // before `filter` (the prop) changed - a click looked like it needed a
  // second try before anything visibly happened. Same fix as
  // ErrorLogFilters/DateRangeSelector: track the clicked value locally so it
  // highlights instantly. Found 2026-09-23.
  const [optimisticFilter, setOptimisticFilter] = useState(filter);

  useEffect(() => setValue(search), [search]);
  useEffect(() => setOptimisticFilter(filter), [filter]);

  function navigate(next: { q?: string; filter?: StoreFilter }) {
    const q = next.q ?? value;
    const f = next.filter ?? filter;
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (f && f !== "all") params.set("filter", f);
    const qs = params.toString();
    startTransition(() => {
      router.push(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    });
  }

  useEffect(() => {
    const handle = setTimeout(() => {
      if (value !== search) navigate({ q: value });
    }, 300);
    return () => clearTimeout(handle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  function handleFilterClick(f: StoreFilter) {
    setOptimisticFilter(f);
    navigate({ filter: f });
  }

  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="relative max-w-sm flex-1">
        <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
        <Input
          placeholder="Search users by name or phone…"
          className="pl-8"
          value={value}
          onChange={(e) => setValue(e.target.value)}
        />
      </div>
      <div className="flex flex-wrap gap-2">
        {FILTERS.map((f) => (
          <Button
            key={f.value}
            size="sm"
            variant={optimisticFilter === f.value ? "default" : "outline"}
            className={cn(pending && optimisticFilter === f.value && "opacity-70")}
            onClick={() => handleFilterClick(f.value)}
          >
            {f.label}
          </Button>
        ))}
      </div>
    </div>
  );
}
