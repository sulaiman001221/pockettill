"use client";

import { usePathname, useRouter } from "next/navigation";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { Button } from "@/components/ui/button";
import type { LogLevelFilter } from "@/lib/data/error-logs";

export function ErrorLogPagination({
  level,
  page,
  pageSize,
  total,
}: {
  level: LogLevelFilter;
  page: number;
  pageSize: number;
  total: number;
}) {
  const router = useRouter();
  const pathname = usePathname();

  if (total === 0) return null;

  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const start = (page - 1) * pageSize + 1;
  const end = Math.min(page * pageSize, total);

  function goTo(nextPage: number) {
    router.push(`${pathname}?level=${level}&page=${nextPage}`, { scroll: false });
  }

  return (
    <div className="flex items-center justify-between gap-4 px-1 py-2">
      <p className="text-sm text-muted-foreground">
        Showing {start}-{end} of {total} results
      </p>
      <div className="flex items-center gap-2">
        <Button size="sm" variant="outline" disabled={page <= 1} onClick={() => goTo(page - 1)}>
          <ChevronLeft className="size-4" />
          Previous
        </Button>
        <Button size="sm" variant="outline" disabled={page >= totalPages} onClick={() => goTo(page + 1)}>
          Next
          <ChevronRight className="size-4" />
        </Button>
      </div>
    </div>
  );
}
