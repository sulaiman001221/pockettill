"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { AuditLogEntry } from "@/lib/data/admin-accounts";
import { formatDateTime } from "@/lib/format";

const PAGE_SIZE = 5;

function actionLabel(action: string) {
  return action.replace(/[._]/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function AuditLogTable({ entries }: { entries: AuditLogEntry[] }) {
  const [expanded, setExpanded] = useState(false);
  const visible = expanded ? entries : entries.slice(0, PAGE_SIZE);
  const remaining = entries.length - visible.length;

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

      {remaining > 0 ? (
        <div className="flex justify-center">
          <Button variant="outline" onClick={() => setExpanded(true)}>
            View More ({remaining} more)
          </Button>
        </div>
      ) : null}
    </>
  );
}
