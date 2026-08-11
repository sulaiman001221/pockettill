import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatCurrency, formatDate, formatMaskedPhone, formatRelativeTime } from "@/lib/format";
import type { CreditCustomerRow } from "@/lib/data/credit-customers";

export function CreditCustomersTable({ customers }: { customers: CreditCustomerRow[] }) {
  return (
    <div className="overflow-hidden rounded-xl bg-card ring-1 ring-border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>Phone</TableHead>
            <TableHead>Balance</TableHead>
            <TableHead>Credit Limit</TableHead>
            <TableHead>Since</TableHead>
            <TableHead>Last activity</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {customers.length === 0 ? (
            <TableRow>
              <TableCell colSpan={6} className="h-24 text-center text-muted-foreground">
                No credit customers match your search.
              </TableCell>
            </TableRow>
          ) : (
            customers.map((customer) => (
              <TableRow key={customer.id}>
                <TableCell className="font-medium">{customer.name}</TableCell>
                <TableCell>{formatMaskedPhone(customer.phone)}</TableCell>
                <TableCell>{formatCurrency(customer.balance)}</TableCell>
                <TableCell>
                  {customer.creditLimit !== null ? formatCurrency(customer.creditLimit) : "—"}
                </TableCell>
                <TableCell>{formatDate(customer.createdAt)}</TableCell>
                <TableCell>{formatRelativeTime(customer.lastActivityAt)}</TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
  );
}
