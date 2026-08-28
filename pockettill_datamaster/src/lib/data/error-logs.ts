import "server-only";
import { describeError } from "@/lib/errors";

// Supabase's public Management API has no simple "get logs" endpoint — logs
// live in a BigQuery-backed analytics store, queried via
// GET /v1/projects/{ref}/analytics/endpoints/logs.all?sql=... using a
// restricted SQL dialect. postgres_logs is the right source here (it
// captures every client's direct Postgres activity — including the mobile
// app's, which never goes through this dashboard — rather than just this
// dashboard's own API calls).
//
// Log severity lives in a nested/repeated `metadata.parsed[].error_severity`
// field. Querying it requires UNNEST, which returned a backend error when
// tested against this project (empty result set either way, so it couldn't
// be verified against a real row). Falling back to a text match against the
// literal "ERROR:"/"WARNING:" prefix Postgres itself writes into every log
// line — less precise than the structured field, but doesn't depend on a
// BigQuery nested-field query shape that couldn't be confirmed live.
const LOGS_ENDPOINT_BASE = "https://api.supabase.com/v1/projects";

export type LogLevel = "error" | "warning" | "info";
export type LogLevelFilter = "error" | "warning" | "all";

export interface ErrorLogEntry {
  id: string;
  timestamp: string;
  level: LogLevel;
  message: string;
  details: unknown;
}

export type ErrorLogsResult =
  | { status: "missing_config" }
  | { status: "error"; message: string }
  | { status: "ok"; data: { entries: ErrorLogEntry[]; total: number } };

function deriveLevel(message: string): LogLevel {
  if (/\b(ERROR|FATAL|PANIC):/i.test(message)) return "error";
  if (/\bWARNING:/i.test(message)) return "warning";
  return "info";
}

function levelWhereClause(filter: LogLevelFilter): string {
  if (filter === "error") {
    return "and (event_message ilike '%ERROR:%' or event_message ilike '%FATAL:%' or event_message ilike '%PANIC:%')";
  }
  if (filter === "warning") {
    return "and event_message ilike '%WARNING:%'";
  }
  return "";
}

async function runLogsQuery(ref: string, apiKey: string, sql: string) {
  const url = `${LOGS_ENDPOINT_BASE}/${ref}/analytics/endpoints/logs.all?sql=${encodeURIComponent(sql)}`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${apiKey}` }, cache: "no-store" });
  if (!res.ok) {
    throw new Error(`Supabase logs API returned ${res.status}.`);
  }
  const json = (await res.json()) as { result: unknown[] | null; error: string | null };
  if (json.error) throw new Error(json.error);
  return json.result ?? [];
}

/** Not cached — logs need to reflect what just happened, and volume here is low enough that it's cheap to query live. */
export async function getErrorLogs(params: {
  level?: LogLevelFilter;
  page?: number;
  pageSize?: number;
}): Promise<ErrorLogsResult> {
  const apiKey = process.env.SUPABASE_MANAGEMENT_API_KEY;
  const projectRef = process.env.SUPABASE_PROJECT_REF;

  if (!apiKey || !projectRef) {
    return { status: "missing_config" };
  }

  const level = params.level ?? "all";
  const pageSize = params.pageSize ?? 10;
  const page = Math.max(1, params.page ?? 1);
  const offset = (page - 1) * pageSize;
  const where = levelWhereClause(level);

  try {
    const [rows, countRows] = await Promise.all([
      runLogsQuery(
        projectRef,
        apiKey,
        `select id, timestamp, event_message, metadata from postgres_logs where true ${where} order by timestamp desc limit ${pageSize} offset ${offset}`
      ),
      runLogsQuery(projectRef, apiKey, `select count(*) as c from postgres_logs where true ${where}`),
    ]);

    const entries: ErrorLogEntry[] = (rows as Record<string, unknown>[]).map((r) => {
      const message = String(r.event_message ?? "");
      return {
        id: String(r.id),
        timestamp: String(r.timestamp),
        level: deriveLevel(message),
        message,
        details: r.metadata ?? null,
      };
    });

    const total = Number((countRows[0] as { c?: number } | undefined)?.c ?? 0);

    return { status: "ok", data: { entries, total } };
  } catch (err) {
    console.error("[error-logs]", err);
    return { status: "error", message: describeError(err) };
  }
}
