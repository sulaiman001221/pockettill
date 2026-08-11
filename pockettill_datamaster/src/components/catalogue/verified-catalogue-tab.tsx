import { Hourglass, PackageCheck } from "lucide-react";

import { CatalogueFilters } from "@/components/catalogue/catalogue-filters";
import { TopCategoriesChart } from "@/components/catalogue/top-categories-chart";
import { VerifiedTable } from "@/components/catalogue/verified-table";
import { KpiCard } from "@/components/shared/kpi-card";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { getCatalogueStats, getCategories, getVerifiedCatalogue } from "@/lib/data/catalogue";

export async function VerifiedCatalogueTab({ search, category }: { search: string; category: string }) {
  const [items, categories, stats, admin] = await Promise.all([
    getVerifiedCatalogue({ search, category }),
    getCategories(),
    getCatalogueStats(),
    getCurrentAdmin(),
  ]);

  const canManage = admin ? canManageStores(admin.role) : false;

  return (
    <div className="flex flex-col gap-6">
      <div className="grid gap-4 sm:grid-cols-2">
        <KpiCard
          label="Total Verified Products"
          value={String(stats.totalVerified)}
          hint="Distinct barcodes"
          icon={<PackageCheck className="size-4.5" />}
          tone="emerald"
        />
        <KpiCard
          label="Pending Verification"
          value={String(stats.totalPending)}
          hint="Distinct barcodes"
          icon={<Hourglass className="size-4.5" />}
          tone="amber"
        />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Top Categories</CardTitle>
          <CardDescription>Verified catalogue composition, by distinct barcode.</CardDescription>
        </CardHeader>
        <CardContent>
          {stats.topCategories.length > 0 ? (
            <TopCategoriesChart data={stats.topCategories} />
          ) : (
            <p className="text-sm text-muted-foreground">No verified products yet.</p>
          )}
        </CardContent>
      </Card>

      <CatalogueFilters search={search} category={category} categories={categories} />
      <VerifiedTable items={items} categories={categories} canManage={canManage} />
    </div>
  );
}
