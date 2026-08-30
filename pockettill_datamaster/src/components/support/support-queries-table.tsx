"use client";

import { useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { toast } from "sonner";

import { Pagination } from "@/components/shared/pagination";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { usePagination } from "@/hooks/use-pagination";
import { saveSupportNotes, updateSupportStatus } from "@/lib/actions/support";
import type { SupportQuery, SupportStatus } from "@/lib/data/support";
import { formatDateTime, formatRelativeTime } from "@/lib/format";
import { cn } from "@/lib/utils";

const STATUS_FILTERS: { label: string; value: string }[] = [
  { label: "All", value: "" },
  { label: "New", value: "new" },
  { label: "In progress", value: "in_progress" },
  { label: "Resolved", value: "resolved" },
];

const STATUS_LABELS: Record<SupportStatus, string> = {
  new: "New",
  in_progress: "In progress",
  resolved: "Resolved",
};

const STATUS_CLASSES: Record<SupportStatus, string> = {
  new: "bg-blue-500/15 text-blue-500",
  in_progress: "bg-amber-500/15 text-amber-500",
  resolved: "bg-emerald-500/15 text-emerald-500",
};

export function SupportQueriesTable({
  queries,
  status,
  search,
  canManage,
}: {
  queries: SupportQuery[];
  status: string;
  search: string;
  canManage: boolean;
}) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [pending, startTransition] = useTransition();

  const [selected, setSelected] = useState<SupportQuery | null>(null);
  const [notes, setNotes] = useState("");
  const [searchValue, setSearchValue] = useState(search);
  const { page, setPage, pageItems, pageSize, total } = usePagination(queries, 10);

  function applyParam(key: string, value: string) {
    const params = new URLSearchParams(searchParams.toString());
    if (value) params.set(key, value);
    else params.delete(key);
    router.push(`/support?${params.toString()}`);
  }

  function openQuery(query: SupportQuery) {
    setSelected(query);
    setNotes(query.internalNotes ?? "");
  }

  function changeStatus(id: string, next: SupportStatus) {
    startTransition(async () => {
      const result = await updateSupportStatus(id, next);
      if (result?.error) {
        toast.error(result.error);
        return;
      }
      toast.success(`Marked as ${STATUS_LABELS[next].toLowerCase()}.`);
      setSelected((current) =>
        current && current.id === id ? { ...current, status: next } : current
      );
      router.refresh();
    });
  }

  function persistNotes(id: string) {
    startTransition(async () => {
      const result = await saveSupportNotes(id, notes);
      if (result?.error) {
        toast.error(result.error);
        return;
      }
      toast.success("Notes saved.");
      router.refresh();
    });
  }

  return (
    <>
      <Card>
        <CardContent className="flex flex-col gap-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="flex flex-wrap items-center gap-1.5">
              {STATUS_FILTERS.map((filter) => (
                <Button
                  key={filter.value || "all"}
                  size="sm"
                  variant={status === filter.value ? "default" : "outline"}
                  onClick={() => applyParam("status", filter.value)}
                >
                  {filter.label}
                </Button>
              ))}
            </div>

            <form
              className="sm:w-64"
              onSubmit={(e) => {
                e.preventDefault();
                applyParam("q", searchValue.trim());
              }}
            >
              <Input
                value={searchValue}
                onChange={(e) => setSearchValue(e.target.value)}
                placeholder="Search name, contact or message"
                aria-label="Search enquiries"
              />
            </form>
          </div>

          {queries.length === 0 ? (
            <p className="py-10 text-center text-sm text-muted-foreground">
              {search || status
                ? "No enquiries match this filter."
                : "No enquiries yet. Messages from the website contact form land here."}
            </p>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>From</TableHead>
                    <TableHead>Contact</TableHead>
                    <TableHead className="hidden md:table-cell">Message</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Received</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {pageItems.map((query) => (
                    <TableRow
                      key={query.id}
                      onClick={() => openQuery(query)}
                      className="cursor-pointer"
                    >
                      <TableCell className="font-medium">{query.name}</TableCell>
                      <TableCell className="text-muted-foreground">{query.contact}</TableCell>
                      <TableCell className="hidden max-w-sm truncate text-muted-foreground md:table-cell">
                        {query.message}
                      </TableCell>
                      <TableCell>
                        <Badge className={cn("border-0", STATUS_CLASSES[query.status])}>
                          {STATUS_LABELS[query.status]}
                        </Badge>
                      </TableCell>
                      <TableCell
                        className="text-right text-muted-foreground"
                        title={formatDateTime(query.createdAt)}
                      >
                        {formatRelativeTime(query.createdAt)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
          <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
        </CardContent>
      </Card>

      <Sheet open={!!selected} onOpenChange={(open) => !open && setSelected(null)}>
        <SheetContent className="flex w-full flex-col gap-0 overflow-y-auto sm:max-w-lg">
          {selected ? (
            <>
              <SheetHeader>
                <SheetTitle>{selected.name}</SheetTitle>
                <SheetDescription>
                  {selected.contact} · {formatDateTime(selected.createdAt)}
                </SheetDescription>
              </SheetHeader>

              <div className="flex flex-col gap-6 px-4 pb-6">
                <div className="flex items-center gap-2">
                  <Badge className={cn("border-0", STATUS_CLASSES[selected.status])}>
                    {STATUS_LABELS[selected.status]}
                  </Badge>
                  {selected.handledByName ? (
                    <span className="text-xs text-muted-foreground">
                      Handled by {selected.handledByName}
                      {selected.handledAt ? ` · ${formatDateTime(selected.handledAt)}` : ""}
                    </span>
                  ) : null}
                </div>

                <div>
                  <h3 className="mb-1.5 text-sm font-medium">Message</h3>
                  <p className="whitespace-pre-wrap rounded-lg bg-muted/50 p-3 text-sm">
                    {selected.message}
                  </p>
                </div>

                {canManage ? (
                  <>
                    <div>
                      <h3 className="mb-1.5 text-sm font-medium">Status</h3>
                      <div className="flex flex-wrap gap-1.5">
                        {(Object.keys(STATUS_LABELS) as SupportStatus[]).map((value) => (
                          <Button
                            key={value}
                            size="sm"
                            disabled={pending || selected.status === value}
                            variant={selected.status === value ? "default" : "outline"}
                            onClick={() => changeStatus(selected.id, value)}
                          >
                            {STATUS_LABELS[value]}
                          </Button>
                        ))}
                      </div>
                    </div>

                    <div>
                      <h3 className="mb-1.5 text-sm font-medium">Internal notes</h3>
                      <textarea
                        value={notes}
                        onChange={(e) => setNotes(e.target.value)}
                        rows={5}
                        placeholder="Only visible to admins."
                        className="w-full resize-none rounded-md border border-input bg-transparent px-3 py-2 text-sm shadow-xs outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50"
                      />
                      <Button
                        size="sm"
                        className="mt-2"
                        disabled={pending || notes === (selected.internalNotes ?? "")}
                        onClick={() => persistNotes(selected.id)}
                      >
                        Save notes
                      </Button>
                    </div>
                  </>
                ) : (
                  <div>
                    <h3 className="mb-1.5 text-sm font-medium">Internal notes</h3>
                    <p className="text-sm text-muted-foreground">
                      {selected.internalNotes || "None."}
                    </p>
                    <p className="mt-3 text-xs text-muted-foreground">
                      Your role has read-only access to support enquiries.
                    </p>
                  </div>
                )}
              </div>
            </>
          ) : null}
        </SheetContent>
      </Sheet>
    </>
  );
}
