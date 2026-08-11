import { NextResponse } from "next/server";

import { createSessionClient } from "@/lib/supabase/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/";
  const supabaseError = searchParams.get("error_description") ?? searchParams.get("error");

  if (supabaseError) {
    return NextResponse.redirect(`${origin}/login?error=link_expired`);
  }

  if (code) {
    const supabase = createSessionClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      return NextResponse.redirect(`${origin}/login?error=link_expired`);
    }
  }

  return NextResponse.redirect(`${origin}${next}`);
}
