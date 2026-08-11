import { notFound } from "next/navigation";

import { BreadcrumbExtra } from "@/components/layout/breadcrumb-context";
import { CreditCustomersSearch } from "@/components/stores/credit-customers-search";
import { CreditCustomersTable } from "@/components/stores/credit-customers-table";
import { PageHeader } from "@/components/shared/page-header";
import { getCreditCustomers } from "@/lib/data/credit-customers";
import { getStoreDetail } from "@/lib/data/stores";

export const metadata = { title: "Credit Customers" };

export default async function CreditCustomersPage({
  params,
  searchParams,
}: {
  params: { storeId: string };
  searchParams: { q?: string };
}) {
  const search = searchParams.q ?? "";

  const [detail, customers] = await Promise.all([
    getStoreDetail(params.storeId),
    getCreditCustomers(params.storeId, search),
  ]);

  if (!detail) {
    notFound();
  }

  return (
    <div className="flex flex-col gap-6">
      <BreadcrumbExtra
        crumbs={[
          { label: detail.store.name, href: `/stores/${params.storeId}` },
          { label: "Credit Customers" },
        ]}
      />
      <PageHeader
        title="Credit Customers"
        description={`Customers with store credit at ${detail.store.name}.`}
      />
      <CreditCustomersSearch search={search} />
      <CreditCustomersTable customers={customers} />
    </div>
  );
}
