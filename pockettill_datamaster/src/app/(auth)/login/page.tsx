import { Suspense } from "react";

import { LoginErrorToast } from "./login-error-toast";
import { LoginForm } from "./login-form";
import { LoginLogo } from "./login-logo";

export const metadata = { title: "Sign in" };

export default function LoginPage() {
  return (
    <div className="flex min-h-svh items-center justify-center p-6">
      <Suspense fallback={null}>
        <LoginErrorToast />
      </Suspense>

      <div className="w-full max-w-sm rounded-xl border p-8">
        <div className="mb-8 flex flex-col items-center gap-6 text-center">
          <LoginLogo />
          <div>
            <h1 className="text-2xl font-semibold">Welcome Back</h1>
            <p className="mt-2 text-sm text-muted-foreground">
              Enter your email and password to access your account.
            </p>
          </div>
        </div>
        <LoginForm />
      </div>
    </div>
  );
}
