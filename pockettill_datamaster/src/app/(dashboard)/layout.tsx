import { redirect } from "next/navigation";

import { AppSidebar } from "@/components/layout/app-sidebar";
import { BreadcrumbProvider } from "@/components/layout/breadcrumb-context";
import { SiteHeader } from "@/components/layout/site-header";
import { SidebarInset, SidebarProvider } from "@/components/ui/sidebar";
import { getCurrentAdmin } from "@/lib/auth";
import { getPendingCatalogueItems } from "@/lib/data/catalogue";
import { getSyncHealthData } from "@/lib/data/sync-health";

export default async function DashboardLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const admin = await getCurrentAdmin();

  if (!admin) {
    redirect("/login");
  }

  const [pendingCatalogue, syncHealth] = await Promise.all([
    getPendingCatalogueItems(),
    getSyncHealthData(),
  ]);

  const badgeCounts = {
    pendingCatalogue: pendingCatalogue.length,
    syncAlerts: syncHealth.critical.length + syncHealth.warning.length,
  };

  return (
    <BreadcrumbProvider>
      <SidebarProvider>
        <AppSidebar
          admin={{ name: admin.fullName, email: admin.email, role: admin.role }}
          badgeCounts={badgeCounts}
        />
        <SidebarInset>
          <SiteHeader />
          <div className="flex flex-1 flex-col gap-4 p-4 md:p-6">{children}</div>
        </SidebarInset>
      </SidebarProvider>
    </BreadcrumbProvider>
  );
}
