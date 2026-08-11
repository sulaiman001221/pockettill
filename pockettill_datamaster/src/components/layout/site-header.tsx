"use client";

import { Fragment } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Search } from "lucide-react";

import { useBreadcrumbContext } from "@/components/layout/breadcrumb-context";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { Input } from "@/components/ui/input";
import { Separator } from "@/components/ui/separator";
import { SidebarTrigger } from "@/components/ui/sidebar";
import { NAV_ITEMS } from "@/config/nav";

export function SiteHeader() {
  const pathname = usePathname();
  const { extra } = useBreadcrumbContext();
  const current =
    NAV_ITEMS.find((item) => (item.href === "/" ? pathname === "/" : pathname.startsWith(item.href))) ??
    NAV_ITEMS[0];

  return (
    <header className="flex h-14 shrink-0 items-center gap-4 border-b px-4">
      <SidebarTrigger className="-ml-1" />
      <Separator orientation="vertical" className="h-4" />
      <Breadcrumb>
        <BreadcrumbList>
          <BreadcrumbItem>
            {extra.length > 0 ? (
              <BreadcrumbLink render={<Link href={current.href} />}>{current.title}</BreadcrumbLink>
            ) : (
              <BreadcrumbPage>{current.title}</BreadcrumbPage>
            )}
          </BreadcrumbItem>
          {extra.map((crumb, i) => {
            const isLast = i === extra.length - 1;
            return (
              <Fragment key={`${crumb.label}-${i}`}>
                <BreadcrumbSeparator />
                <BreadcrumbItem>
                  {crumb.href && !isLast ? (
                    <BreadcrumbLink render={<Link href={crumb.href} />}>{crumb.label}</BreadcrumbLink>
                  ) : (
                    <BreadcrumbPage>{crumb.label}</BreadcrumbPage>
                  )}
                </BreadcrumbItem>
              </Fragment>
            );
          })}
        </BreadcrumbList>
      </Breadcrumb>
      <form action="/stores" className="relative ml-auto w-full max-w-sm">
        <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input name="q" placeholder="Search users…" className="h-9 pl-8" />
      </form>
    </header>
  );
}
