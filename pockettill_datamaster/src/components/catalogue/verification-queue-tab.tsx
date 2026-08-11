import { PendingList } from "@/components/catalogue/pending-list";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { getCategories, getPendingCatalogueItems } from "@/lib/data/catalogue";

export async function VerificationQueueTab() {
  const [items, categories, admin] = await Promise.all([
    getPendingCatalogueItems(),
    getCategories(),
    getCurrentAdmin(),
  ]);

  const canManage = admin ? canManageStores(admin.role) : false;

  return <PendingList items={items} categories={categories} canManage={canManage} />;
}
