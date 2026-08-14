import "server-only";
import { unstable_cache } from "next/cache";
import { createServiceRoleClient } from "@/lib/supabase/server";

/** Tag used to bust every cached read in this file after a support mutation. */
export const SUPPORT_CACHE_TAG = "support";

export const SUPPORT_STATUSES = ["new", "in_progress", "resolved"] as const;
export type SupportStatus = (typeof SUPPORT_STATUSES)[number];

export interface SupportQuery {
  id: string;
  name: string;
  contact: string;
  message: string;
  status: SupportStatus;
  source: string;
  internalNotes: string | null;
  handledBy: string | null;
  handledByName: string | null;
  handledAt: string | null;
  createdAt: string;
}

export interface SupportStats {
  newCount: number;
  inProgressCount: number;
  resolvedCount: number;
  total: number;
}

interface SupportRow {
  id: string;
  name: string;
  contact: string;
  message: string;
  status: string;
  source: string;
  internal_notes: string | null;
  handled_by: string | null;
  handled_at: string | null;
  created_at: string;
  // Supabase returns an embedded row (or null) for the handled_by FK.
  admin_users: { full_name: string | null; email: string } | null;
}

async function _getSupportQueries(
  params: { status?: string; search?: string } = {}
): Promise<SupportQuery[]> {
  const supabase = createServiceRoleClient();

  let query = supabase
    .from("support_queries")
    .select(
      "id, name, contact, message, status, source, internal_notes, handled_by, handled_at, created_at, admin_users:handled_by (full_name, email)"
    );

  if (params.status && SUPPORT_STATUSES.includes(params.status as SupportStatus)) {
    query = query.eq("status", params.status);
  }

  // Strip PostgREST's `or()` delimiters so a stray comma or bracket in the
  // search box can't break out of the filter expression.
  const search = params.search?.trim().replace(/[(),]/g, "");
  if (search) {
    query = query.or(
      `name.ilike.%${search}%,contact.ilike.%${search}%,message.ilike.%${search}%`
    );
  }

  const { data, error } = await query.order("created_at", { ascending: false });
  if (error) throw new Error(error.message);

  return ((data ?? []) as unknown as SupportRow[]).map((r) => ({
    id: r.id,
    name: r.name,
    contact: r.contact,
    message: r.message,
    status: r.status as SupportStatus,
    source: r.source,
    internalNotes: r.internal_notes,
    handledBy: r.handled_by,
    handledByName: r.admin_users?.full_name || r.admin_users?.email || null,
    handledAt: r.handled_at,
    createdAt: r.created_at,
  }));
}

export const getSupportQueries = unstable_cache(_getSupportQueries, ["support-queries"], {
  tags: [SUPPORT_CACHE_TAG],
  revalidate: 20,
});

async function _getSupportStats(): Promise<SupportStats> {
  const supabase = createServiceRoleClient();

  const [{ count: newCount }, { count: inProgressCount }, { count: resolvedCount }, { count: total }] =
    await Promise.all([
      supabase.from("support_queries").select("*", { count: "exact", head: true }).eq("status", "new"),
      supabase
        .from("support_queries")
        .select("*", { count: "exact", head: true })
        .eq("status", "in_progress"),
      supabase
        .from("support_queries")
        .select("*", { count: "exact", head: true })
        .eq("status", "resolved"),
      supabase.from("support_queries").select("*", { count: "exact", head: true }),
    ]);

  return {
    newCount: newCount ?? 0,
    inProgressCount: inProgressCount ?? 0,
    resolvedCount: resolvedCount ?? 0,
    total: total ?? 0,
  };
}

export const getSupportStats = unstable_cache(_getSupportStats, ["support-stats"], {
  tags: [SUPPORT_CACHE_TAG],
  revalidate: 20,
});

/** Count of unhandled enquiries, for the sidebar badge. */
async function _getNewSupportCount(): Promise<number> {
  const supabase = createServiceRoleClient();
  const { count } = await supabase
    .from("support_queries")
    .select("*", { count: "exact", head: true })
    .eq("status", "new");
  return count ?? 0;
}

export const getNewSupportCount = unstable_cache(_getNewSupportCount, ["support-new-count"], {
  tags: [SUPPORT_CACHE_TAG],
  revalidate: 20,
});
