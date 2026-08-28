"use client";

import { useRouter } from "next/navigation";
import { ChevronRight } from "lucide-react";

import { FoundingToggleCell } from "@/components/stores/founding-toggle-cell";
import { PhoneEditCell } from "@/components/stores/phone-edit-cell";
import { Pagination } from "@/components/shared/pagination";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
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
import { formatDate, formatRelativeTime } from "@/lib/format";
import type { StoreListRow } from "@/lib/data/stores";

function initials(name: string) {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();
}

export function StoresTable({
  stores,
  canManage = false,
}: {
  stores: StoreListRow[];
  canManage?: boolean;
}) {
  const router = useRouter();
  const { page, setPage, pageItems, pageSize, total } = usePagination(stores, 10);

  return (
    <div className="flex flex-col gap-2">
    <div className="overflow-hidden rounded-xl bg-card ring-1 ring-border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Store</TableHead>
            <TableHead>Phone</TableHead>
            <TableHead>Registered</TableHead>
            <TableHead>Last sync</TableHead>
            <TableHead>Founding</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="w-8" />
          </TableRow>
        </TableHeader>
        <TableBody>
          {pageItems.length === 0 ? (
            <TableRow>
              <TableCell colSpan={7} className="h-24 text-center text-muted-foreground">
                No stores match your filters.
              </TableCell>
            </TableRow>
          ) : (
            pageItems.map((store) => (
              <TableRow
                key={store.id}
                className="cursor-pointer"
                onClick={() => router.push(`/stores/${store.id}`)}
              >
                <TableCell className="font-medium">
                  <div className="flex items-center gap-2.5">
                    <Avatar size="sm">
                      <AvatarFallback>{initials(store.name)}</AvatarFallback>
                    </Avatar>
                    {store.name}
                  </div>
                </TableCell>
                <TableCell>
                  <PhoneEditCell
                    storeId={store.id}
                    storeName={store.name}
                    phone={store.phone}
                    canManage={canManage}
                  />
                </TableCell>
                <TableCell>{formatDate(store.createdAt)}</TableCell>
                <TableCell>{formatRelativeTime(store.lastSyncedAt)}</TableCell>
                <TableCell>
                  <FoundingToggleCell
                    storeId={store.id}
                    storeName={store.name}
                    isFounding={store.isFounding}
                    canManage={canManage}
                  />
                </TableCell>
                <TableCell>
                  {store.active ? (
                    <Badge className="border-transparent bg-emerald-500/10 text-emerald-500">Active</Badge>
                  ) : (
                    <Badge variant="outline">Inactive</Badge>
                  )}
                </TableCell>
                <TableCell>
                  <ChevronRight className="size-4 text-muted-foreground" />
                </TableCell>
              </TableRow>
            ))
          )}
        </TableBody>
      </Table>
    </div>
    <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />
    </div>
  );
}
