import "server-only";
import { unstable_cache } from "next/cache";
import { createServiceRoleClient } from "@/lib/supabase/server";

export interface CreditCustomerRow {
  id: string;
  name: string;
  phone: string;
  balance: number;
  creditLimit: number | null;
  createdAt: string;
  lastActivityAt: string | null;
}

async function _getCreditCustomers(storeId: string, search = ""): Promise<CreditCustomerRow[]> {
  const supabase = createServiceRoleClient();

  let query = supabase
    .from("credit_customers")
    .select("uuid, name, phone, balance, credit_limit, created_at, last_activity_at")
    .eq("store_id", storeId);

  const trimmed = search.trim().replace(/[(),]/g, "");
  if (trimmed) {
    query = query.or(`name.ilike.%${trimmed}%,phone.ilike.%${trimmed}%`);
  }

  query = query.order("balance", { ascending: false });

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  return (data ?? []).map((r) => ({
    id: r.uuid,
    name: r.name,
    phone: r.phone,
    balance: Number(r.balance),
    creditLimit: r.credit_limit !== null ? Number(r.credit_limit) : null,
    createdAt: r.created_at,
    lastActivityAt: r.last_activity_at,
  }));
}

/** Not admin-mutated — populated by the POS app, safe to cache briefly with time-based revalidation only. */
export const getCreditCustomers = unstable_cache(_getCreditCustomers, ["credit-customers"], {
  tags: ["credit-customers"],
  revalidate: 30,
});
