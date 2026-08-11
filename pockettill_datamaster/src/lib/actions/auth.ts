"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { createSessionClient } from "@/lib/supabase/server";

export type LoginState = { error?: string } | undefined;

function siteOrigin() {
  const h = headers();
  return h.get("origin") ?? `https://${h.get("host")}`;
}

export async function login(_prevState: LoginState, formData: FormData): Promise<LoginState> {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const remember = formData.get("remember") === "on";

  if (!email || !password) {
    return { error: "Enter your email and password." };
  }

  const supabase = createSessionClient({ persistSession: remember });

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error || !data.user) {
    return { error: "Invalid email or password." };
  }

  const { data: adminUser } = await supabase
    .from("admin_users")
    .select("is_active")
    .eq("id", data.user.id)
    .maybeSingle();

  if (!adminUser?.is_active) {
    await supabase.auth.signOut();
    return { error: "This account is not an authorized admin." };
  }

  redirect("/");
}

export async function logout() {
  const supabase = createSessionClient();
  await supabase.auth.signOut();
  redirect("/login");
}

export type RequestResetState = { error?: string; success?: boolean } | undefined;

export async function requestPasswordReset(
  _prevState: RequestResetState,
  formData: FormData
): Promise<RequestResetState> {
  const email = String(formData.get("email") ?? "").trim();

  if (!email) {
    return { error: "Enter your email." };
  }

  const supabase = createSessionClient();
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: `${siteOrigin()}/auth/callback?next=/reset-password`,
  });

  if (error) {
    return { error: "Could not send reset email. Try again." };
  }

  return { success: true };
}

export type UpdatePasswordState = { error?: string } | undefined;

export async function updatePassword(
  _prevState: UpdatePasswordState,
  formData: FormData
): Promise<UpdatePasswordState> {
  const password = String(formData.get("password") ?? "");
  const confirmPassword = String(formData.get("confirmPassword") ?? "");

  if (password.length < 8) {
    return { error: "Password must be at least 8 characters." };
  }

  if (password !== confirmPassword) {
    return { error: "Passwords do not match." };
  }

  const supabase = createSessionClient();
  const { error } = await supabase.auth.updateUser({ password });

  if (error) {
    return { error: "Could not update your password. Request a new reset link and try again." };
  }

  redirect("/");
}
