import "server-only";
import { unstable_cache } from "next/cache";
import { createServiceRoleClient } from "@/lib/supabase/server";

/** Tag used to bust every cached read in this file after a catalogue mutation. */
export const CATALOGUE_CACHE_TAG = "catalogue";

export interface PendingCatalogueItem {
  barcode: string;
  nameVariations: string[];
  categoryVariations: (string | null)[];
  storeCount: number;
  firstSubmitted: string;
  mostCommonName: string;
  mostCommonCategory: string | null;
  mostCommonMass: string | null;
}

export interface VerifiedCatalogueItem {
  barcode: string;
  name: string;
  category: string | null;
  mass: string | null;
  verifiedAt: string | null;
  storeCount: number;
}

export interface CatalogueStats {
  totalVerified: number;
  totalPending: number;
  topCategories: { category: string; count: number }[];
}

async function _getPendingCatalogueItems(): Promise<PendingCatalogueItem[]> {
  const supabase = createServiceRoleClient();
  const { data, error } = await supabase
    .from("pending_catalogue_items")
    .select(
      "barcode, name_variations, category_variations, store_count, first_submitted, most_common_name, most_common_category, most_common_mass"
    )
    .order("first_submitted", { ascending: true });

  if (error) throw new Error(error.message);

  return (data ?? []).map((r) => ({
    barcode: r.barcode,
    nameVariations: r.name_variations ?? [],
    categoryVariations: r.category_variations ?? [],
    storeCount: r.store_count,
    firstSubmitted: r.first_submitted,
    mostCommonName: r.most_common_name,
    mostCommonCategory: r.most_common_category,
    mostCommonMass: r.most_common_mass,
  }));
}

export const getPendingCatalogueItems = unstable_cache(
  _getPendingCatalogueItems,
  ["pending-catalogue-items"],
  { tags: [CATALOGUE_CACHE_TAG], revalidate: 20 }
);

async function _getVerifiedCatalogue(
  params: { search?: string; category?: string } = {}
): Promise<VerifiedCatalogueItem[]> {
  const supabase = createServiceRoleClient();

  let query = supabase
    .from("verified_catalogue_items")
    .select("barcode, name, category, mass, verified_at, store_count");

  const search = params.search?.trim().replace(/[(),]/g, "");
  if (search) {
    query = query.or(`name.ilike.%${search}%,barcode.ilike.%${search}%`);
  }
  if (params.category) {
    query = query.eq("category", params.category);
  }

  query = query.order("name", { ascending: true });

  const { data, error } = await query;
  if (error) throw new Error(error.message);

  return (data ?? []).map((r) => ({
    barcode: r.barcode,
    name: r.name,
    category: r.category,
    mass: r.mass,
    verifiedAt: r.verified_at,
    storeCount: r.store_count,
  }));
}

export const getVerifiedCatalogue = unstable_cache(_getVerifiedCatalogue, ["verified-catalogue"], {
  tags: [CATALOGUE_CACHE_TAG],
  revalidate: 20,
});

/** Distinct categories across every product ever submitted (verified or not), for the picker in the approve/edit panel. */
async function _getCategories(): Promise<string[]> {
  const supabase = createServiceRoleClient();
  const { data, error } = await supabase.from("products").select("category").not("category", "is", null);

  if (error) throw new Error(error.message);

  const set = new Set((data ?? []).map((r) => r.category as string));
  return Array.from(set).sort();
}

export const getCategories = unstable_cache(_getCategories, ["catalogue-categories"], {
  tags: [CATALOGUE_CACHE_TAG],
  revalidate: 60,
});

async function _getCatalogueStats(): Promise<CatalogueStats> {
  const supabase = createServiceRoleClient();

  const [{ count: totalVerified }, { count: totalPending }, { data: categoryRows }] = await Promise.all([
    supabase.from("verified_catalogue_items").select("*", { count: "exact", head: true }),
    supabase.from("pending_catalogue_items").select("*", { count: "exact", head: true }),
    supabase.from("verified_catalogue_items").select("category"),
  ]);

  const counts = new Map<string, number>();
  for (const row of categoryRows ?? []) {
    const cat = row.category ?? "Uncategorized";
    counts.set(cat, (counts.get(cat) ?? 0) + 1);
  }

  const topCategories = Array.from(counts.entries())
    .map(([category, count]) => ({ category, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 5);

  return {
    totalVerified: totalVerified ?? 0,
    totalPending: totalPending ?? 0,
    topCategories,
  };
}

export const getCatalogueStats = unstable_cache(_getCatalogueStats, ["catalogue-stats"], {
  tags: [CATALOGUE_CACHE_TAG],
  revalidate: 20,
});
