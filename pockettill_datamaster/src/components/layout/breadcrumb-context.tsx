"use client";

import { createContext, useContext, useEffect, useState } from "react";

export interface BreadcrumbCrumb {
  label: string;
  href?: string;
}

interface BreadcrumbContextValue {
  extra: BreadcrumbCrumb[];
  setExtra: (crumbs: BreadcrumbCrumb[]) => void;
}

const BreadcrumbContext = createContext<BreadcrumbContextValue | null>(null);

export function BreadcrumbProvider({ children }: { children: React.ReactNode }) {
  const [extra, setExtra] = useState<BreadcrumbCrumb[]>([]);
  return (
    <BreadcrumbContext.Provider value={{ extra, setExtra }}>{children}</BreadcrumbContext.Provider>
  );
}

export function useBreadcrumbContext() {
  const ctx = useContext(BreadcrumbContext);
  if (!ctx) throw new Error("useBreadcrumbContext must be used within a BreadcrumbProvider.");
  return ctx;
}

/**
 * Render inside a leaf page to append trailing breadcrumb segments after the
 * sidebar nav item, e.g. a store name. Clears itself on unmount so the
 * breadcrumb doesn't leak into unrelated pages.
 */
export function BreadcrumbExtra({ crumbs }: { crumbs: BreadcrumbCrumb[] }) {
  const { setExtra } = useBreadcrumbContext();
  const key = JSON.stringify(crumbs);

  useEffect(() => {
    setExtra(crumbs);
    return () => setExtra([]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  return null;
}
