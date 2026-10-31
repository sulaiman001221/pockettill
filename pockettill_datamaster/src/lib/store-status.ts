/** A store with no sync for this many days is shown as Inactive. */
export const INACTIVE_AFTER_DAYS = 30;

export type StoreStatus = "active" | "deactivated" | "dormant";

/**
 * A store's status as shown in DataMaster. Derived on every read - nothing is
 * stored - so a dormant store returns to Active the moment it syncs again.
 *
 * - "deactivated": an admin switched the store off (`stores.active = false`).
 *   Stays inactive no matter how recently it synced.
 * - "dormant": no sync in the last [INACTIVE_AFTER_DAYS] days. A store that has
 *   never synced is measured from when it registered.
 */
export function getStoreStatus(
  active: boolean,
  lastSyncedAt: string | null,
  createdAt: string,
  now: number = Date.now()
): StoreStatus {
  if (!active) return "deactivated";
  const lastActivity = new Date(lastSyncedAt ?? createdAt).getTime();
  const cutoff = now - INACTIVE_AFTER_DAYS * 24 * 60 * 60 * 1000;
  return lastActivity >= cutoff ? "active" : "dormant";
}
