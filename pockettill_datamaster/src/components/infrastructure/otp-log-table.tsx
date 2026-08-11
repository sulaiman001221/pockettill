"use client";

import { useState } from "react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDateTime, formatMaskedPhone } from "@/lib/format";
import type { TwilioOtpLogEntry } from "@/lib/costs/twilio";

const PAGE_SIZE = 5;

export function OtpLogTable({ entries }: { entries: TwilioOtpLogEntry[] }) {
  const [expanded, setExpanded] = useState(false);
  const visible = expanded ? entries : entries.slice(0, PAGE_SIZE);
  const remaining = entries.length - visible.length;

  return (
    <>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Phone</TableHead>
            <TableHead>Channel</TableHead>
            <TableHead>Status</TableHead>
            <TableHead>Date</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {visible.length === 0 ? (
            <TableRow>
              <TableCell colSpan={4} className="h-20 text-center text-muted-foreground">
                No recent OTP activity.
              </TableCell>
            </TableRow>
          ) : (
            visible.map((entry, i) => (
              <TableRow key={i}>
                <TableCell>{formatMaskedPhone(entry.phone)}</TableCell>
                <TableCell className="capitalize">{entry.channel}</TableCell>
                <TableCell>
                  {entry.status === "converted" ? (
                    <Badge className="border-transparent bg-emerald-500/10 text-emerald-500">
                      Converted
                    </Badge>
                  ) : (
                    <Badge variant="outline" className="capitalize">
                      {entry.status}
                    </Badge>
                  )}
                </TableCell>
                <TableCell>{formatDateTime(entry.date)}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>

      {remaining > 0 ? (
        <div className="flex justify-center pt-4">
          <Button variant="outline" onClick={() => setExpanded(true)}>
            View More ({remaining} more)
          </Button>
        </div>
      ) : null}
    </>
  );
}
