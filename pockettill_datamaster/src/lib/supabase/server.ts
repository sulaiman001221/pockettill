import "server-only";
import { createServerClient } from "@supabase/ssr";
import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { cookies } from "next/headers";

/**
 * Service-role client: bypasses RLS entirely. Use for all admin dashboard
 * data queries (stores, sales, products, etc). Never import this into
 * client components — the "server-only" import above throws a build error
 * if that happens.
 */
export function createServiceRoleClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new Error("Missing Supabase service role environment variables.");
  }

  return createSupabaseClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

/**
 * Session-scoped client: acts as the currently logged-in admin (RLS
 * enforced), backed by the auth cookies set at login. Use for reading the
 * current admin's identity/role and for sign-in/sign-out in Server Actions.
 */
export function createSessionClient(options?: { persistSession?: boolean }) {
  const cookieStore = cookies();
  const persistSession = options?.persistSession ?? true;

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(
                name,
                value,
                // "Remember me" unchecked: drop expiry so the auth cookies
                // behave as session-only and clear when the browser closes.
                persistSession ? options : { ...options, maxAge: undefined, expires: undefined }
              )
            );
          } catch {
            // Called from a Server Component render, which can't set
            // cookies. Safe to ignore — middleware refreshes the session
            // on the next request.
          }
        },
      },
    }
  );
}
