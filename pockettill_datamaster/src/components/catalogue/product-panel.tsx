"use client";

import { useEffect, useState, useTransition } from "react";
import { toast } from "sonner";

import { approveProduct, updateVerifiedProduct } from "@/lib/actions/catalogue";
import { formatProductMass, formatProductName } from "@/lib/catalogue-format";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";

export interface ProductPanelItem {
  barcode: string;
  name: string;
  category: string;
  mass: string;
}

const OTHER_VALUE = "__other__";

export function ProductPanel({
  mode,
  item,
  categories,
  open,
  onOpenChange,
}: {
  mode: "approve" | "edit";
  item: ProductPanelItem | null;
  categories: string[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
}) {
  const [name, setName] = useState("");
  const [categorySelect, setCategorySelect] = useState("");
  const [customCategory, setCustomCategory] = useState("");
  const [mass, setMass] = useState("");
  const [conflict, setConflict] = useState<{ existingName: string } | null>(null);
  const [pending, startTransition] = useTransition();

  useEffect(() => {
    setConflict(null);
    if (item) {
      // Approving is the point where a product enters the shared catalogue,
      // so the admin sees (and can still hand-correct) the canonical form
      // up front rather than being surprised by a diff after saving. Editing
      // an already-verified product shows the stored value as-is.
      setName(mode === "approve" ? formatProductName(item.name) : item.name);
      setMass(mode === "approve" ? formatProductMass(item.mass) : item.mass);
      if (item.category && categories.includes(item.category)) {
        setCategorySelect(item.category);
        setCustomCategory("");
      } else if (item.category) {
        setCategorySelect(OTHER_VALUE);
        setCustomCategory(item.category);
      } else {
        setCategorySelect("");
        setCustomCategory("");
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [item]);

  const category = categorySelect === OTHER_VALUE ? customCategory.trim() : categorySelect;

  function handleConfirm(force = false) {
    if (!item) return;

    startTransition(async () => {
      if (mode === "approve") {
        const result = await approveProduct(item.barcode, { name, category, mass }, { force });
        if (result?.conflict) {
          setConflict(result.conflict);
        } else if (result?.error) {
          toast.error(result.error);
        } else {
          toast.success("Product approved.");
          onOpenChange(false);
        }
        return;
      }

      const result = await updateVerifiedProduct(item.barcode, { name, category, mass });
      if (result?.error) {
        toast.error(result.error);
      } else {
        toast.success("Product updated.");
        onOpenChange(false);
      }
    });
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{mode === "approve" ? "Approve Product" : "Edit Product"}</SheetTitle>
          <SheetDescription>
            {mode === "approve"
              ? "Review and confirm the canonical details for this barcode."
              : "Update the canonical details for this barcode."}
          </SheetDescription>
        </SheetHeader>

        <div className="flex flex-col gap-4 px-4">
          <div className="grid gap-2">
            <Label>Barcode</Label>
            <Input value={item?.barcode ?? ""} readOnly disabled className="font-mono" />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="product-name">Name</Label>
            <Input id="product-name" value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="grid gap-2">
            <Label>Category</Label>
            <Select value={categorySelect} onValueChange={(v) => v && setCategorySelect(v)}>
              <SelectTrigger className="w-full">
                <SelectValue placeholder="Select category" />
              </SelectTrigger>
              <SelectContent>
                {categories.map((c) => (
                  <SelectItem key={c} value={c}>
                    {c}
                  </SelectItem>
                ))}
                <SelectItem value={OTHER_VALUE}>Other</SelectItem>
              </SelectContent>
            </Select>
            {categorySelect === OTHER_VALUE ? (
              <Input
                value={customCategory}
                onChange={(e) => setCustomCategory(e.target.value)}
                placeholder="Enter custom category"
                autoFocus
              />
            ) : null}
          </div>
          <div className="grid gap-2">
            <Label htmlFor="product-mass">Mass</Label>
            <Input id="product-mass" value={mass} onChange={(e) => setMass(e.target.value)} />
          </div>
        </div>

        <SheetFooter>
          <Button onClick={() => handleConfirm()} disabled={pending || !name || !category}>
            {mode === "approve" ? "Approve" : "Save changes"}
          </Button>
        </SheetFooter>
      </SheetContent>

      <Dialog open={conflict !== null} onOpenChange={(next) => !next && setConflict(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Barcode already verified</DialogTitle>
            <DialogDescription>
              This barcode already exists as &quot;{conflict?.existingName}&quot;. Do you want to update
              the existing product with these details, or cancel?
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setConflict(null)}>
              Cancel
            </Button>
            <Button
              disabled={pending}
              onClick={() => {
                setConflict(null);
                handleConfirm(true);
              }}
            >
              Update existing product
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Sheet>
  );
}
