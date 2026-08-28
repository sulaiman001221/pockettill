"use server";

import { revalidateTag } from "next/cache";

export async function retryTwilioCosts() {
  revalidateTag("twilio-costs");
}

export async function retrySupabaseCosts() {
  revalidateTag("supabase-costs");
}

export async function retryWebsiteTraffic() {
  revalidateTag("ga4-traffic");
}
