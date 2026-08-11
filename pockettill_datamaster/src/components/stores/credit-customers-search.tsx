"use client";

import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Search } from "lucide-react";

import { Input } from "@/components/ui/input";

export function CreditCustomersSearch({ search }: { search: string }) {
  const router = useRouter();
  const pathname = usePathname();
  const [value, setValue] = useState(search);

  useEffect(() => setValue(search), [search]);

  useEffect(() => {
    const handle = setTimeout(() => {
      if (value !== search) {
        const params = new URLSearchParams();
        if (value) params.set("q", value);
        const qs = params.toString();
        router.push(qs ? `${pathname}?${qs}` : pathname);
      }
    }, 300);
    return () => clearTimeout(handle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  return (
    <div className="relative max-w-sm">
      <Search className="absolute top-2.5 left-2.5 size-4 text-muted-foreground" />
      <Input
        placeholder="Search customers by name or phone…"
        className="pl-8"
        value={value}
        onChange={(e) => setValue(e.target.value)}
      />
    </div>
  );
}
