"use client";

import { Fragment, useState } from "react";
import { ChevronDown, ChevronRight } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDateTime } from "@/lib/format";
import type { ErrorLogEntry, LogLevel } from "@/lib/data/error-logs";

const LEVEL_BADGE: Record<LogLevel, string> = {
  error: "bg-red-500/10 text-red-500",
  warning: "bg-amber-500/10 text-amber-500",
  info: "bg-blue-500/10 text-blue-500",
};

export function ErrorLogTable({ entries }: { entries: ErrorLogEntry[] }) {
  const [expandedId, setExpandedId] = useState<string | null>(null);

  return (
    <div className="overflow-hidden rounded-xl bg-card ring-1 ring-border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-8" />
            <TableHead>Timestamp</TableHead>
            <TableHead>Level</TableHead>
            <TableHead>Message</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {entries.length === 0 ? (
            <TableRow>
              <TableCell colSpan={4} className="h-24 text-center text-muted-foreground">
                No logs in this period.
              </TableCell>
            </TableRow>
          ) : (
            entries.map((entry) => {
              const isExpanded = expandedId === entry.id;
              return (
                <Fragment key={entry.id}>
                  <TableRow
                    className="cursor-pointer"
                    onClick={() => setExpandedId(isExpanded ? null : entry.id)}
                  >
                    <TableCell>
                      {isExpanded ? (
                        <ChevronDown className="size-4 text-muted-foreground" />
                      ) : (
                        <ChevronRight className="size-4 text-muted-foreground" />
                      )}
                    </TableCell>
                    <TableCell className="whitespace-nowrap">{formatDateTime(entry.timestamp)}</TableCell>
                    <TableCell>
                      <Badge className={`border-transparent capitalize ${LEVEL_BADGE[entry.level]}`}>
                        {entry.level}
                      </Badge>
                    </TableCell>
                    <TableCell className="max-w-xl truncate font-mono text-xs">{entry.message}</TableCell>
                  </TableRow>
                  {isExpanded ? (
                    <TableRow>
                      <TableCell colSpan={4} className="bg-muted/30">
                        <pre className="max-h-64 overflow-auto whitespace-pre-wrap break-all text-xs">
                          {entry.message}
                          {entry.details ? `\n\n${JSON.stringify(entry.details, null, 2)}` : ""}
                        </pre>
                      </TableCell>
                    </TableRow>
                  ) : null}
                </Fragment>
              );
            })
          )}
        </TableBody>
      </Table>
    </div>
  );
}
