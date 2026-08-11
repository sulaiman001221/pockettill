import { redirect } from "next/navigation";

import { PageHeader } from "@/components/shared/page-header";
import { ThemeSelector } from "@/components/settings/theme-selector";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { getCurrentAdmin } from "@/lib/auth";

export const metadata = { title: "Settings" };

export default async function SettingsPage() {
  const admin = await getCurrentAdmin();

  if (!admin) {
    redirect("/login");
  }

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="Settings" description="Manage your admin profile and appearance." />

      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
          <CardDescription>Your admin account details.</CardDescription>
        </CardHeader>
        <CardContent className="grid gap-4 sm:max-w-sm">
          <div className="grid gap-1.5">
            <Label>Name</Label>
            <p className="text-sm text-muted-foreground">{admin.fullName}</p>
          </div>
          <div className="grid gap-1.5">
            <Label>Email</Label>
            <p className="text-sm text-muted-foreground">{admin.email}</p>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Appearance</CardTitle>
          <CardDescription>Choose how DataMaster looks on this device.</CardDescription>
        </CardHeader>
        <CardContent>
          <ThemeSelector />
        </CardContent>
      </Card>
    </div>
  );
}
