"use client";

import { useState } from "react";
import { CheckCircle2 } from "lucide-react";

import { ProductPanel, type ProductPanelItem } from "@/components/catalogue/product-panel";
import { RejectDialog } from "@/components/catalogue/reject-dialog";
import { Pagination } from "@/components/shared/pagination";
import { Badge, badgeVariants } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { usePagination } from "@/hooks/use-pagination";
import { formatDate } from "@/lib/format";
import type { PendingCatalogueItem } from "@/lib/data/catalogue";

export function PendingList({
  items,
  categories,
  canManage,
}: {
  items: PendingCatalogueItem[];
  categories: string[];
  canManage: boolean;
}) {
  const [panelItem, setPanelItem] = useState<ProductPanelItem | null>(null);
  const [panelOpen, setPanelOpen] = useState(false);
  const [rejectBarcode, setRejectBarcode] = useState<string | null>(null);
  const { page, setPage, pageItems, pageSize, total } = usePagination(items, 10);

  function openApprove(item: PendingCatalogueItem) {
    setPanelItem({
      barcode: item.barcode,
      name: item.mostCommonName,
      category: item.mostCommonCategory ?? "",
      mass: item.mostCommonMass ?? "",
    });
    setPanelOpen(true);
  }

  if (items.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center gap-3 rounded-xl bg-card py-16 text-center ring-1 ring-border">
        <CheckCircle2 className="size-8 text-emerald-500" />
        <p className="text-sm font-medium">No products pending verification</p>
      </div>
    );
  }

  return (
    <>
      <div className="overflow-hidden rounded-xl bg-card ring-1 ring-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Barcode</TableHead>
              <TableHead>Name</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Mass</TableHead>
              <TableHead>Submitted by</TableHead>
              <TableHead>First submitted</TableHead>
              {canManage ? <TableHead className="text-right">Actions</TableHead> : null}
            </TableRow>
          </TableHeader>
          <TableBody>
            {pageItems.map((item) => (
              <TableRow key={item.barcode}>
                <TableCell className="font-mono text-xs">{item.barcode}</TableCell>
                <TableCell>
                  <div className="flex max-w-56 flex-wrap gap-1">
                    {item.nameVariations.map((n) => (
                      <Tooltip key={n}>
                        <TooltipTrigger
                          render={
                            <span className={`${badgeVariants({ variant: "secondary" })} max-w-56 truncate`}>
                              {n}
                            </span>
                          }
                        />
                        <TooltipContent>{n}</TooltipContent>
                      </Tooltip>
                    ))}
                  </div>
                </TableCell>
                <TableCell>
                  <div className="flex max-w-40 flex-wrap gap-1">
                    {item.categoryVariations.map((c) => (
                      <Badge key={c ?? "none"} variant="outline">
                        {c ?? "Uncategorized"}
                      </Badge>
                    ))}
                  </div>
                </TableCell>
                <TableCell>{item.mostCommonMass ?? "—"}</TableCell>
                <TableCell>
                  {item.storeCount} store{item.storeCount === 1 ? "" : "s"}
                </TableCell>
                <TableCell>{formatDate(item.firstSubmitted)}</TableCell>
                {canManage ? (
                  <TableCell className="text-right">
                    <div className="flex justify-end gap-2">
                      <Button size="sm" variant="outline" onClick={() => openApprove(item)}>
                        Approve
                      </Button>
                      <Button size="sm" variant="destructive" onClick={() => setRejectBarcode(item.barcode)}>
                        Reject
                      </Button>
                    </div>
                  </TableCell>
                ) : null}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>

      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />

      <ProductPanel
        mode="approve"
        item={panelItem}
        categories={categories}
        open={panelOpen}
        onOpenChange={setPanelOpen}
      />
      <RejectDialog barcode={rejectBarcode} onOpenChange={(open) => !open && setRejectBarcode(null)} />
    </>
  );
}
