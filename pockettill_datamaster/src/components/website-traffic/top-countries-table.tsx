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
import type { GA4TopCountry } from "@/lib/integrations/ga4";

export function TopCountriesTable({ countries }: { countries: GA4TopCountry[] }) {
  const { page, setPage, pageItems, pageSize, total } = usePagination(countries, 10);

  return (
    <>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Country</TableHead>
            <TableHead className="text-right">Visitors</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {pageItems.length === 0 ? (
            <TableRow>
              <TableCell colSpan={2} className="h-20 text-center text-muted-foreground">
                No visitors yet.
              </TableCell>
            </TableRow>
          ) : (
            pageItems.map((c) => (
              <TableRow key={c.country}>
                <TableCell>{c.country}</TableCell>
                <TableCell className="text-right">{c.users}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
    </>
  );
}
