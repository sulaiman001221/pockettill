import "server-only";
import { createServiceRoleClient } from "@/lib/supabase/server";

/**
 * Records an admin action to the audit trail. Fire-and-forget by design —
 * a logging failure should never block or roll back the action it's
 * describing, so callers don't need to (and shouldn't) await error handling
 * on this beyond letting it resolve.
 */
export async function logAudit(
  adminId: string,
  action: string,
  target: string,
  metadata: Record<string, unknown> = {}
) {
  const supabase = createServiceRoleClient();
  await supabase.from("audit_log").insert({ admin_id: adminId, action, target, metadata });
}
