"use client";

import { Pagination } from "@/components/shared/pagination";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { usePagination } from "@/hooks/use-pagination";
import type { AuditLogEntry } from "@/lib/data/admin-accounts";
import { formatDateTime } from "@/lib/format";

function actionLabel(action: string) {
  return action.replace(/[._]/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function AuditLogTable({ entries }: { entries: AuditLogEntry[] }) {
  const { page, setPage, pageItems: visible, pageSize, total } = usePagination(entries, 10);

  return (
    <>
      <div className="overflow-hidden rounded-xl bg-card ring-1 ring-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Admin</TableHead>
              <TableHead>Action</TableHead>
              <TableHead>Target</TableHead>
              <TableHead>Date</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {visible.length === 0 ? (
              <TableRow>
                <TableCell colSpan={4} className="h-24 text-center text-muted-foreground">
                  No actions recorded yet.
                </TableCell>
              </TableRow>
            ) : (
              visible.map((entry) => (
                <TableRow key={entry.id}>
                  <TableCell className="font-medium">{entry.adminName}</TableCell>
                  <TableCell>{actionLabel(entry.action)}</TableCell>
                  <TableCell className="max-w-64 truncate">{entry.target}</TableCell>
                  <TableCell>{formatDateTime(entry.createdAt)}</TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
    </>
  );
}
