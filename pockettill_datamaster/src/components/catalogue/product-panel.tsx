"use client";

import { useEffect, useRef, useState, useTransition } from "react";
import { toast } from "sonner";

import {
  approveProduct,
  updateVerifiedProduct,
  uploadEnhancedCatalogueImage,
} from "@/lib/actions/catalogue";
import { formatProductMass, formatProductName } from "@/lib/catalogue-format";
import { compressImageFile } from "@/lib/image-compress";
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
  imageUrl?: string | null;
  /** Existing admin-enhanced replacement, if this barcode already has one -
   * null/undefined for a barcode that's never been enhanced (including
   * every barcode reaching the panel in "approve" mode, which by
   * definition isn't in catalogue_products yet). */
  enhancedImageUrl?: string | null;
}

const OTHER_VALUE = "__other__";

/** File size + pixel dimensions for a remote image URL, loaded client-side -
 * best-effort, shows "—" for whatever it can't determine rather than
 * blocking the rest of the panel on it. */
function RemoteImageMeta({ url }: { url: string }) {
  const [dims, setDims] = useState<string | null>(null);
  const [size, setSize] = useState<string | null>(null);

  useEffect(() => {
    setDims(null);
    setSize(null);

    const img = new Image();
    img.onload = () => setDims(`${img.naturalWidth}×${img.naturalHeight}px`);
    img.onerror = () => setDims("—");
    img.src = url;

    let cancelled = false;
    fetch(url, { method: "HEAD" })
      .then((res) => {
        if (cancelled) return;
        const bytes = Number(res.headers.get("content-length"));
        setSize(bytes > 0 ? `${(bytes / 1024).toFixed(0)} KB` : "—");
      })
      .catch(() => {
        if (!cancelled) setSize("—");
      });

    return () => {
      cancelled = true;
    };
  }, [url]);

  return (
    <p className="text-xs text-muted-foreground">
      {dims ?? "Loading…"} · {size ?? "Loading…"}
    </p>
  );
}

/** One side of the Original/Enhanced image comparison. */
function ImagePanel({
  label,
  url,
  emptyHint,
  action,
}: {
  label: string;
  url: string | null;
  emptyHint: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="grid gap-2">
      <div className="flex items-center justify-between">
        <Label>{label}</Label>
        {action}
      </div>
      {url ? (
        <>
          {/* eslint-disable-next-line @next/next/no-img-element -- arbitrary external domain (Open Food Facts, a store's own Supabase Storage upload, or this admin's own enhanced-image bucket), not worth a next.config.js remotePatterns wildcard for an admin-only thumbnail */}
          <img src={url} alt="" className="h-32 w-32 rounded-lg border border-border object-cover" />
          <RemoteImageMeta url={url} />
        </>
      ) : (
        <div className="flex h-32 w-32 items-center justify-center rounded-lg border border-dashed border-border text-center text-xs text-muted-foreground">
          {emptyHint}
        </div>
      )}
    </div>
  );
}

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

  const [enhancedUrl, setEnhancedUrl] = useState<string | null>(null);
  // Tracks whether the admin actually interacted with the Enhanced panel
  // this session (upload or Clear) - distinct from enhancedUrl's value,
  // because "cleared back to null" and "never touched, still null" must be
  // told apart on save. Comparing enhancedUrl against item.enhancedImageUrl
  // doesn't work for that: clearing an *existing* enhancement makes
  // enhancedUrl (null) different from item.enhancedImageUrl (the old URL),
  // which read as "a change" - but the change was silently treated as "set
  // the enhanced image to null" and skipped by the falsy check in
  // updateVerifiedProduct, so Clear appeared to do nothing (found
  // 2026-09-08).
  const [enhancedTouched, setEnhancedTouched] = useState(false);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setConflict(null);
    setEnhancedUrl(item?.enhancedImageUrl ?? null);
    setEnhancedTouched(false);
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

  async function handlePickEnhancedImage(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = ""; // allow re-picking the same file later
    if (!file || !item) return;

    setUploading(true);
    // Compress before upload - an admin's source photo can easily be 1MB+,
    // wildly out of step with every store-submitted original (~50KB, since
    // the app compresses those before upload). See image-compress.ts.
    const compressed = await compressImageFile(file);
    const formData = new FormData();
    formData.append("file", compressed, "enhanced.jpg");
    const result = await uploadEnhancedCatalogueImage(item.barcode, formData);
    setUploading(false);

    if (result.error) {
      toast.error(result.error);
      return;
    }
    setEnhancedUrl(result.url ?? null);
    setEnhancedTouched(true);
  }

  function handleConfirm(force = false) {
    if (!item) return;

    // "approve" always sends the current enhanced state (null is a valid,
    // meaningful "no enhanced image"); "edit" only signals a change when
    // it's actually different from what was already saved, so a plain
    // name/category/mass correction doesn't touch the image columns.
    const enhancedImageUrl =
      mode === "approve"
        ? enhancedUrl
        : enhancedTouched
          ? enhancedUrl
          : undefined;

    startTransition(async () => {
      if (mode === "approve") {
        const result = await approveProduct(
          item.barcode,
          { name, category, mass },
          { force, enhancedImageUrl }
        );
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

      const result = await updateVerifiedProduct(
        item.barcode,
        { name, category, mass },
        { enhancedImageUrl }
      );
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
          <div className="grid grid-cols-2 gap-3">
            <ImagePanel
              label="Original"
              url={item?.imageUrl ?? null}
              emptyHint="No photo submitted"
            />
            <ImagePanel
              label="Enhanced (Catalogue)"
              url={enhancedUrl}
              emptyHint="No enhanced image yet"
              action={
                enhancedUrl ? (
                  <button
                    type="button"
                    onClick={() => {
                      setEnhancedUrl(null);
                      setEnhancedTouched(true);
                    }}
                    className="text-xs text-muted-foreground underline-offset-2 hover:underline"
                  >
                    Clear
                  </button>
                ) : undefined
              }
            />
          </div>
          <div>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handlePickEnhancedImage}
            />
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={uploading}
              onClick={() => fileInputRef.current?.click()}
            >
              {uploading ? "Uploading…" : "Upload Enhanced Image"}
            </Button>
          </div>
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
          <Button onClick={() => handleConfirm()} disabled={pending || uploading || !name || !category}>
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
