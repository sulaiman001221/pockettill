import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { GA4TopPage } from "@/lib/integrations/ga4";

export function TopPagesTable({ pages }: { pages: GA4TopPage[] }) {
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Page</TableHead>
          <TableHead className="text-right">Views</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {pages.length === 0 ? (
          <TableRow>
            <TableCell colSpan={2} className="h-20 text-center text-muted-foreground">
              No page views yet.
            </TableCell>
          </TableRow>
        ) : (
          pages.map((page) => (
            <TableRow key={page.path}>
              <TableCell className="max-w-48 truncate font-mono text-xs">
                {page.path === "/" ? "Home" : page.path}
              </TableCell>
              <TableCell className="text-right">{page.views}</TableCell>
            </TableRow>
          ))
        )}
      </TableBody>
    </Table>
  );
}
