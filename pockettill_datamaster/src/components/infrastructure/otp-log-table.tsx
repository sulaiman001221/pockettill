"use client";

import { Pagination } from "@/components/shared/pagination";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { usePagination } from "@/hooks/use-pagination";
import { formatDateTime, formatMaskedPhone } from "@/lib/format";
import type { TwilioOtpLogEntry } from "@/lib/costs/twilio";

export function OtpLogTable({ entries }: { entries: TwilioOtpLogEntry[] }) {
  const { page, setPage, pageItems: visible, pageSize, total } = usePagination(entries, 10);

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

      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
    </>
  );
}
