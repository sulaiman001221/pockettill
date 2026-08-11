"use client";

import { NavMain, type NavBadgeCounts } from "@/components/layout/nav-main";
import { NavUser, type AdminIdentity } from "@/components/layout/nav-user";
import { SidebarLogo } from "@/components/layout/sidebar-logo";
import { Sidebar, SidebarContent, SidebarFooter, SidebarHeader } from "@/components/ui/sidebar";

export function AppSidebar({
  admin,
  badgeCounts,
  ...props
}: React.ComponentProps<typeof Sidebar> & {
  admin: AdminIdentity;
  badgeCounts?: NavBadgeCounts;
}) {
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader className="h-14 flex-row items-center justify-start border-b border-sidebar-border px-4 group-data-[collapsible=icon]:justify-center group-data-[collapsible=icon]:px-0">
        <SidebarLogo />
      </SidebarHeader>
      <SidebarContent>
        <NavMain badgeCounts={badgeCounts} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser admin={admin} />
      </SidebarFooter>
    </Sidebar>
  );
}
