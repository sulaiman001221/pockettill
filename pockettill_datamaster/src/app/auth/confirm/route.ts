import { NextResponse } from "next/server";
import type { EmailOtpType } from "@supabase/supabase-js";

import { createSessionClient } from "@/lib/supabase/server";

/**
 * Handles admin-invite (and any other token_hash-based) email links.
 *
 * `/auth/callback` only works for flows the *browser* initiated (it stores a
 * PKCE code_verifier cookie itself, e.g. self-service password reset) — an
 * admin-triggered invite has no browser session to anchor a code_verifier
 * to, so Supabase can only issue a token_hash/type link for it, never a
 * `code`. This route verifies that token_hash server-side instead, per
 * Supabase's documented pattern for email-triggered auth flows in SSR apps.
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const next = searchParams.get("next") ?? "/";

  if (tokenHash && type) {
    const supabase = createSessionClient();
    const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/login?error=invite_expired`);
}
