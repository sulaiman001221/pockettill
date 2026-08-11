import "server-only";
import { unstable_cache } from "next/cache";
import { createServiceRoleClient } from "@/lib/supabase/server";

// Verified 2026-08-10 against the real Management API and this project.
// Supabase's public Management API has NO endpoint for database/storage
// size — `GET /v1/projects/{ref}/usage` (the original spec's assumption)
// returns a genuine 404. The only real usage endpoints are
// `analytics/endpoints/usage.api-counts` and `usage.api-requests-count`.
// Plan lives at the organization level, not the project level. Database
// and storage size instead come from `database_usage_bytes()`, a Postgres
// function called via the service-role client — see SCHEMA_TRUTH.md.

export interface SupabaseCostData {
  plan: string;
  dbSizeBytes: number | null;
  storageSizeBytes: number | null;
  apiRequestsThisMonth: number | null;
}

export type SupabaseCostResult =
  | { status: "missing_config" }
  | { status: "error"; message: string }
  | { status: "ok"; data: SupabaseCostData };

async function _getSupabaseCostData(): Promise<SupabaseCostResult> {
  const apiKey = process.env.SUPABASE_MANAGEMENT_API_KEY;
  const projectRef = process.env.SUPABASE_PROJECT_REF;

  if (!apiKey || !projectRef) {
    return { status: "missing_config" };
  }

  try {
    const authHeader = { Authorization: `Bearer ${apiKey}` };

    const projectRes = await fetch(`https://api.supabase.com/v1/projects/${projectRef}`, {
      headers: authHeader,
      cache: "no-store",
    });

    if (!projectRes.ok) {
      return { status: "error", message: `Supabase project API returned ${projectRes.status}.` };
    }

    const project = await projectRes.json();
    const orgSlug: string | undefined = project.organization_slug ?? project.organization_id;

    const [orgRes, requestsRes, bytesRes] = await Promise.all([
      orgSlug
        ? fetch(`https://api.supabase.com/v1/organizations/${orgSlug}`, {
            headers: authHeader,
            cache: "no-store",
          })
        : null,
      fetch(`https://api.supabase.com/v1/projects/${projectRef}/analytics/endpoints/usage.api-requests-count`, {
        headers: authHeader,
        cache: "no-store",
      }),
      createServiceRoleClient().rpc("database_usage_bytes"),
    ]);

    const org = orgRes?.ok ? await orgRes.json() : null;
    const requestsJson = requestsRes.ok ? await requestsRes.json() : null;
    const requestsCount = requestsJson?.result?.[0]?.count ?? null;

    const bytesRow = bytesRes.data?.[0] as
      | { db_size_bytes: number; storage_size_bytes: number }
      | undefined;

    return {
      status: "ok",
      data: {
        plan: org?.plan ?? "Unknown",
        dbSizeBytes: bytesRow?.db_size_bytes ?? null,
        storageSizeBytes: bytesRow?.storage_size_bytes ?? null,
        apiRequestsThisMonth: requestsCount,
      },
    };
  } catch (err) {
    return { status: "error", message: err instanceof Error ? err.message : "Unknown error" };
  }
}

/** External Supabase Management API call — safe to cache for several minutes. */
export const getSupabaseCostData = unstable_cache(_getSupabaseCostData, ["supabase-cost-data"], {
  tags: ["supabase-costs"],
  revalidate: 180,
});
