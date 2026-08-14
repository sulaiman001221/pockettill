"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

import {
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuBadge,
  SidebarMenuButton,
  SidebarMenuItem,
  useSidebar,
} from "@/components/ui/sidebar";
import { NAV_GROUPS, NAV_ITEMS } from "@/config/nav";

export interface NavBadgeCounts {
  pendingCatalogue?: number;
  syncAlerts?: number;
  newSupport?: number;
}

export function NavMain({ badgeCounts = {} }: { badgeCounts?: NavBadgeCounts }) {
  const pathname = usePathname();
  // Tooltips only render anything when the sidebar is icon-collapsed (see
  // SidebarMenuButton), but wrapping every link in a Tooltip/TooltipTrigger
  // regardless still wires up Base UI's hover/pointer-intent machinery —
  // that's what made fast repeated clicks in expanded mode feel like they
  // needed a second click to register. Skip the wrapper entirely when it
  // can't show anything anyway.
  const { state, isMobile, setOpenMobile } = useSidebar();
  const showTooltips = state === "collapsed" && !isMobile;

  function handleNavClick() {
    if (isMobile) setOpenMobile(false);
  }

  return (
    <>
      {NAV_GROUPS.map((group) => (
        <SidebarGroup key={group}>
          <SidebarGroupLabel>{group.toUpperCase()}</SidebarGroupLabel>
          <SidebarMenu>
            {NAV_ITEMS.filter((item) => item.group === group).map((item) => {
              const isActive =
                item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
              const badgeCount = item.badgeKey ? badgeCounts[item.badgeKey] : undefined;

              return (
                <SidebarMenuItem key={item.href}>
                  <SidebarMenuButton
                    isActive={isActive}
                    tooltip={showTooltips ? item.title : undefined}
                    render={
                      <Link href={item.href} onClick={handleNavClick}>
                        <item.icon />
                        <span>{item.title}</span>
                      </Link>
                    }
                  />
                  {badgeCount ? (
                    <SidebarMenuBadge className="bg-primary/15 text-primary">
                      {badgeCount}
                    </SidebarMenuBadge>
                  ) : null}
                </SidebarMenuItem>
              );
            })}
          </SidebarMenu>
        </SidebarGroup>
      ))}
    </>
  );
}
