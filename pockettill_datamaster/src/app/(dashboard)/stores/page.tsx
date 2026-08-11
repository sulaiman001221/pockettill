import { StoresFilters } from "@/components/stores/stores-filters";
import { StoresTable } from "@/components/stores/stores-table";
import { PageHeader } from "@/components/shared/page-header";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { getStoresList, type StoreFilter } from "@/lib/data/stores";

export const metadata = { title: "Users" };

const VALID_FILTERS: StoreFilter[] = ["all", "active", "inactive", "founding"];

export default async function StoresPage({
  searchParams,
}: {
  searchParams: { q?: string; filter?: string };
}) {
  const search = searchParams.q ?? "";
  const filter = VALID_FILTERS.includes(searchParams.filter as StoreFilter)
    ? (searchParams.filter as StoreFilter)
    : "all";

  const [stores, admin] = await Promise.all([getStoresList({ search, filter }), getCurrentAdmin()]);
  const canManage = admin ? canManageStores(admin.role) : false;

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Users" description="Search, filter, and drill into individual store accounts." />
      <StoresFilters search={search} filter={filter} />
      <StoresTable stores={stores} canManage={canManage} />
    </div>
  );
}
