"use client";

import { useState } from "react";
import { CheckCircle2 } from "lucide-react";

import { ProductPanel, type ProductPanelItem } from "@/components/catalogue/product-panel";
import { RejectDialog } from "@/components/catalogue/reject-dialog";
import { Pagination } from "@/components/shared/pagination";
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
      imageUrl: item.mostCommonImageUrl,
      // Not yet in catalogue_products by definition (this is the pending
      // queue), so there's no existing enhanced image to show - the panel
      // starts empty and any upload here becomes the catalogue image on
      // approval.
      enhancedImageUrl: null,
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
              <TableHead>Image</TableHead>
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
                <TableCell>
                  {item.mostCommonImageUrl ? (
                    // eslint-disable-next-line @next/next/no-img-element -- arbitrary external domain, see product-panel.tsx
                    <img
                      src={item.mostCommonImageUrl}
                      alt=""
                      className="size-10 rounded-md border border-border object-cover"
                    />
                  ) : (
                    <div className="size-10 rounded-md bg-muted" />
                  )}
                </TableCell>
                <TableCell className="font-mono text-xs">{item.barcode}</TableCell>
                <TableCell className="font-medium">
                  <div className="flex max-w-56 items-center gap-1.5">
                    <Tooltip>
                      <TooltipTrigger render={<span className="block max-w-56 truncate">{item.mostCommonName}</span>} />
                      <TooltipContent>{item.mostCommonName}</TooltipContent>
                    </Tooltip>
                    {item.nameVariations.length > 1 ? (
                      <Tooltip>
                        <TooltipTrigger
                          render={
                            <span className="shrink-0 rounded-full bg-muted px-1.5 py-0.5 text-[0.7rem] text-muted-foreground">
                              +{item.nameVariations.length - 1}
                            </span>
                          }
                        />
                        <TooltipContent>
                          Also submitted as: {item.nameVariations.filter((n) => n !== item.mostCommonName).join(", ")}
                        </TooltipContent>
                      </Tooltip>
                    ) : null}
                  </div>
                </TableCell>
                <TableCell>
                  {(() => {
                    // Same "most common, +N others in a tooltip" pattern
                    // as the Name column above - this used to render every
                    // distinct submitted category as its own always-visible
                    // badge, so a barcode a few stores had each categorized
                    // slightly differently (free-text, not a controlled
                    // list - "Snacks" vs "snacks" vs a trailing space all
                    // count as distinct) grew a badge per submission with
                    // no cap, overflowing into neighbouring columns. Found
                    // 2026-09-23.
                    const others = item.categoryVariations.filter(
                      (c) => c !== item.mostCommonCategory,
                    );
                    return (
                      <div className="flex max-w-40 items-center gap-1.5">
                        <Badge variant="outline" className="shrink-0 truncate">
                          {item.mostCommonCategory ?? "Uncategorized"}
                        </Badge>
                        {others.length > 0 ? (
                          <Tooltip>
                            <TooltipTrigger
                              render={
                                <span className="shrink-0 rounded-full bg-muted px-1.5 py-0.5 text-[0.7rem] text-muted-foreground">
                                  +{others.length}
                                </span>
                              }
                            />
                            <TooltipContent>
                              Also submitted as:{" "}
                              {others.map((c) => c ?? "Uncategorized").join(", ")}
                            </TooltipContent>
                          </Tooltip>
                        ) : null}
                      </div>
                    );
                  })()}
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
