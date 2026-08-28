"use client";

import { useState } from "react";

import { ProductPanel, type ProductPanelItem } from "@/components/catalogue/product-panel";
import { UnverifyDialog } from "@/components/catalogue/unverify-dialog";
import { Pagination } from "@/components/shared/pagination";
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
import type { VerifiedCatalogueItem } from "@/lib/data/catalogue";

export function VerifiedTable({
  items,
  categories,
  canManage,
}: {
  items: VerifiedCatalogueItem[];
  categories: string[];
  canManage: boolean;
}) {
  const [panelItem, setPanelItem] = useState<ProductPanelItem | null>(null);
  const [panelOpen, setPanelOpen] = useState(false);
  const [removeBarcode, setRemoveBarcode] = useState<string | null>(null);
  const { page, setPage, pageItems: visibleItems, pageSize, total } = usePagination(items, 10);

  function openEdit(item: VerifiedCatalogueItem) {
    setPanelItem({
      barcode: item.barcode,
      name: item.name,
      category: item.category ?? "",
      mass: item.mass ?? "",
    });
    setPanelOpen(true);
  }

  return (
    <>
      {/*
        min-h keeps this container from collapsing to a sliver when a search
        narrows the result set down to nothing/one row - without it, the
        page's total height would suddenly shrink by hundreds of pixels and
        the search bar above (still scrolled past, mid-page) would appear to
        jump toward the bottom of a now much-shorter page.
      */}
      <div className="min-h-[26rem] overflow-hidden rounded-xl bg-card ring-1 ring-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Barcode</TableHead>
              <TableHead>Name</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Mass</TableHead>
              <TableHead>Verified</TableHead>
              {canManage ? <TableHead className="text-right">Actions</TableHead> : null}
            </TableRow>
          </TableHeader>
          <TableBody>
            {visibleItems.length === 0 ? (
              <TableRow>
                <TableCell colSpan={canManage ? 6 : 5} className="h-96 text-center text-muted-foreground">
                  No verified products match your filters.
                </TableCell>
              </TableRow>
            ) : (
              visibleItems.map((item) => (
                <TableRow key={item.barcode}>
                  <TableCell className="font-mono text-xs">{item.barcode}</TableCell>
                  <TableCell className="font-medium">
                    <Tooltip>
                      <TooltipTrigger render={<span className="block max-w-64 truncate">{item.name}</span>} />
                      <TooltipContent>{item.name}</TooltipContent>
                    </Tooltip>
                  </TableCell>
                  <TableCell>{item.category ?? "—"}</TableCell>
                  <TableCell>{item.mass ?? "—"}</TableCell>
                  <TableCell>{formatDate(item.verifiedAt)}</TableCell>
                  {canManage ? (
                    <TableCell className="text-right">
                      <div className="flex justify-end gap-2">
                        <Button size="sm" variant="outline" onClick={() => openEdit(item)}>
                          Edit
                        </Button>
                        <Button size="sm" variant="outline" onClick={() => setRemoveBarcode(item.barcode)}>
                          Remove
                        </Button>
                      </div>
                    </TableCell>
                  ) : null}
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <Pagination page={page} pageSize={pageSize} total={total} onPageChange={setPage} />

      <ProductPanel
        mode="edit"
        item={panelItem}
        categories={categories}
        open={panelOpen}
        onOpenChange={setPanelOpen}
      />
      <UnverifyDialog barcode={removeBarcode} onOpenChange={(open) => !open && setRemoveBarcode(null)} />
    </>
  );
}
