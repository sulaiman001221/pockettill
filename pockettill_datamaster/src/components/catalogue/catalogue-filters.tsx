"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Search } from "lucide-react";

import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";

export function CatalogueFilters({
  search,
  category,
  categories,
}: {
  search: string;
  category: string;
  categories: string[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [value, setValue] = useState(search);

  useEffect(() => setValue(search), [search]);

  function navigate(next: { q?: string; category?: string }) {
    const q = next.q ?? value;
    const cat = next.category ?? category;
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (cat && cat !== "all") params.set("category", cat);
    const qs = params.toString();
    router.push(qs ? `${pathname}?${qs}` : pathname);
  }

  useEffect(() => {
    const handle = setTimeout(() => {
      if (value !== search) navigate({ q: value });
    }, 300);
    return () => clearTimeout(handle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
      <div className="relative max-w-sm flex-1">
        <Search className="absolute left-2.5 top-2.5 size-4 text-muted-foreground" />
        <Input
          placeholder="Search by name or barcode…"
          className="pl-8"
          value={value}
          onChange={(e) => setValue(e.target.value)}
        />
      </div>
      <Select value={category || "all"} onValueChange={(v) => navigate({ category: v ?? "all" })}>
        <SelectTrigger className="w-full sm:w-48">
          <SelectValue placeholder="All categories" />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value="all">All categories</SelectItem>
          {categories.map((c) => (
            <SelectItem key={c} value={c}>
              {c}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
