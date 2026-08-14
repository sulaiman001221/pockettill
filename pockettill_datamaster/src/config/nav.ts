import type { LucideIcon } from "lucide-react";
import {
  LayoutDashboard,
  Users,
  RefreshCw,
  PackageSearch,
  BarChart3,
  Server,
  Globe,
  LifeBuoy,
  ShieldCheck,
} from "lucide-react";

export type AdminRole = "owner" | "editor" | "viewer";

export type NavGroup = "Overview" | "Operations" | "Insights" | "Administration";

export interface NavItem {
  title: string;
  href: string;
  icon: LucideIcon;
  description: string;
  group: NavGroup;
  /** Key into the sidebar badge-count map built in the dashboard layout. */
  badgeKey?: "pendingCatalogue" | "syncAlerts" | "newSupport";
}

export const NAV_ITEMS: NavItem[] = [
  {
    title: "Overview",
    href: "/",
    icon: LayoutDashboard,
    description: "KPI cards and platform health",
    group: "Overview",
  },
  {
    title: "Users",
    href: "/stores",
    icon: Users,
    description: "List, search, filter, store detail",
    group: "Operations",
  },
  {
    title: "Sync Health",
    href: "/sync-health",
    icon: RefreshCw,
    description: "Stores not synced, trend charts",
    group: "Operations",
    badgeKey: "syncAlerts",
  },
  {
    title: "Product Catalogue",
    href: "/product-catalogue",
    icon: PackageSearch,
    description: "Verification queue and verified list",
    group: "Operations",
    badgeKey: "pendingCatalogue",
  },
  {
    title: "Support",
    href: "/support",
    icon: LifeBuoy,
    description: "Contact enquiries from the website",
    group: "Operations",
    badgeKey: "newSupport",
  },
  {
    title: "Analytics",
    href: "/analytics",
    icon: BarChart3,
    description: "Aggregated platform-wide charts",
    group: "Insights",
  },
  {
    title: "Infrastructure Costs",
    href: "/infrastructure-costs",
    icon: Server,
    description: "Twilio and Supabase usage costs",
    group: "Insights",
  },
  {
    title: "Website Traffic",
    href: "/website-traffic",
    icon: Globe,
    description: "GA4 reporting",
    group: "Insights",
  },
  {
    title: "Admin Accounts",
    href: "/admin-accounts",
    icon: ShieldCheck,
    description: "Invite, roles, audit log",
    group: "Administration",
  },
];

export const NAV_GROUPS: NavGroup[] = ["Overview", "Operations", "Insights", "Administration"];
