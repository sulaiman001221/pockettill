import { NextResponse } from "next/server";
import { CONTACT_HINT, isValidContact } from "@/lib/validate";

// Inserts contact-form submissions into Supabase `support_queries`, which
// pockettill_datamaster reads in its Support section. The table has RLS on
// with no policies, so it is only reachable with the service-role key — which
// must never leave the server. Keep this route on the Node runtime.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const LIMITS = { name: 120, contact: 160, message: 4000 };

function field(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function fail(message: string, status: number) {
  return NextResponse.json({ error: message }, { status });
}

export async function POST(request: Request) {
  let payload: Record<string, unknown>;

  try {
    payload = await request.json();
  } catch {
    return fail("Could not read that request.", 400);
  }

  // Honeypot: real users never see this input, so anything in it is a bot.
  // Return success so the bot has no signal that it was rejected.
  if (field(payload.website)) {
    return NextResponse.json({ ok: true });
  }

  const name = field(payload.name);
  const contact = field(payload.contact);
  const message = field(payload.message);

  if (!name || !contact || !message) {
    return fail("Please fill in every field.", 400);
  }

  if (
    name.length > LIMITS.name ||
    contact.length > LIMITS.contact ||
    message.length > LIMITS.message
  ) {
    return fail("That message is a bit too long — please shorten it.", 400);
  }

  if (!isValidContact(contact)) {
    return fail(CONTACT_HINT, 400);
  }

  const url = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    console.error("[contact] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return fail("Messaging is unavailable right now. Please try WhatsApp.", 500);
  }

  const response = await fetch(`${url}/rest/v1/support_queries`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({ name, contact, message, source: "landing" }),
    cache: "no-store",
  });

  if (!response.ok) {
    // Log the cause server-side; never surface Supabase internals to the browser.
    console.error(
      `[contact] Supabase insert failed (${response.status}): ${await response.text()}`,
    );
    return fail("Could not send your message. Please try WhatsApp instead.", 502);
  }

  return NextResponse.json({ ok: true });
}
