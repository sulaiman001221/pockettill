import Link from "next/link";
import { notFound } from "next/navigation";

import { BreadcrumbExtra } from "@/components/layout/breadcrumb-context";
import { StoreActions } from "@/components/stores/store-actions";
import { KpiCard } from "@/components/shared/kpi-card";
import { PageHeader } from "@/components/shared/page-header";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { canManageStores, getCurrentAdmin } from "@/lib/auth";
import { getStoreDetail } from "@/lib/data/stores";
import { formatCurrency, formatDate, formatDateTime, formatMaskedPhone, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Store detail" };

export default async function StoreDetailPage({
  params,
}: {
  params: { storeId: string };
}) {
  const [detail, admin] = await Promise.all([getStoreDetail(params.storeId), getCurrentAdmin()]);

  if (!detail) {
    notFound();
  }

  const { store, syncHistory, sales, credit, devices } = detail;
  const canManage = admin ? canManageStores(admin.role) : false;

  const daysSinceRegistration = Math.max(
    1,
    Math.floor((Date.now() - new Date(store.createdAt).getTime()) / (24 * 60 * 60 * 1000))
  );
  const avgDailyRevenue = sales.totalRevenue / daysSinceRegistration;
  const avgBasketSize = sales.count > 0 ? sales.totalRevenue / sales.count : 0;

  return (
    <div className="flex flex-col gap-6">
      <BreadcrumbExtra crumbs={[{ label: store.name }]} />
      <PageHeader title={store.name} description="Store profile and activity." />

      <Card>
        <CardContent className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div>
            <p className="text-sm text-muted-foreground">Phone</p>
            <p className="font-medium">{formatMaskedPhone(store.phone)}</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Registered</p>
            <p className="font-medium">{formatDate(store.createdAt)}</p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Founding store</p>
            <p className="font-medium">
              {store.isFounding ? (
                <Badge variant="secondary">Founding</Badge>
              ) : (
                <span className="text-muted-foreground">No</span>
              )}
            </p>
          </div>
          <div>
            <p className="text-sm text-muted-foreground">Status</p>
            {store.active ? (
              <Badge className="border-transparent bg-emerald-500/10 text-emerald-500">Active</Badge>
            ) : (
              <Badge variant="outline">Inactive</Badge>
            )}
          </div>
        </CardContent>
      </Card>

      {canManage ? (
        <StoreActions
          storeId={store.id}
          storeName={store.name}
          isFounding={store.isFounding}
          active={store.active}
        />
      ) : null}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        <KpiCard label="Total Sales" value={String(sales.count)} />
        <KpiCard label="Total Revenue" value={formatCurrency(sales.totalRevenue)} />
        <KpiCard label="Avg Daily Revenue" value={formatCurrency(avgDailyRevenue)} />
        <KpiCard label="Avg Basket Size" value={formatCurrency(avgBasketSize)} />
        <Link href={`/stores/${store.id}/credit-customers`}>
          <KpiCard
            label="Credit Customers"
            value={String(credit.count)}
            className="cursor-pointer transition-shadow hover:ring-2 hover:ring-primary/40"
          />
        </Link>
        <KpiCard label="Outstanding Balance" value={formatCurrency(credit.totalOutstanding)} />
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Sync History</CardTitle>
        </CardHeader>
        <CardContent className="px-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>When</TableHead>
                <TableHead>Device</TableHead>
                <TableHead>Pushed</TableHead>
                <TableHead>Pulled</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {syncHistory.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4} className="h-20 text-center text-muted-foreground">
                    No sync events yet.
                  </TableCell>
                </TableRow>
              ) : (
                syncHistory.map((event) => (
                  <TableRow key={event.id}>
                    <TableCell>{formatDateTime(event.createdAt)}</TableCell>
                    <TableCell className="font-mono text-xs">{event.deviceId}</TableCell>
                    <TableCell>{event.eventsPushed}</TableCell>
                    <TableCell>{event.eventsPulled}</TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Devices</CardTitle>
        </CardHeader>
        <CardContent className="px-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Device ID</TableHead>
                <TableHead>Verified</TableHead>
                <TableHead>Last seen</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {devices.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={3} className="h-20 text-center text-muted-foreground">
                    No devices registered yet.
                  </TableCell>
                </TableRow>
              ) : (
                devices.map((device) => (
                  <TableRow key={device.id}>
                    <TableCell className="font-mono text-xs">{device.id}</TableCell>
                    <TableCell>
                      {device.verifiedAt ? (
                        <Badge className="border-transparent bg-emerald-500/10 text-emerald-500">Verified</Badge>
                      ) : (
                        <Badge variant="outline">Unverified</Badge>
                      )}
                    </TableCell>
                    <TableCell>{formatRelativeTime(device.lastSeenAt)}</TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
