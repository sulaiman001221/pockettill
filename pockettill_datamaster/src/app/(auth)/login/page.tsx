import Image from "next/image";
import { Suspense } from "react";

import { LoginErrorToast } from "./login-error-toast";
import { LoginForm } from "./login-form";

export const metadata = { title: "Sign in" };

export default function LoginPage() {
  return (
    <div className="grid min-h-svh lg:grid-cols-2">
      <Suspense fallback={null}>
        <LoginErrorToast />
      </Suspense>
      <div className="relative flex flex-col justify-center overflow-hidden bg-[#5170FF] p-10 text-white">
        <div className="pointer-events-none absolute -top-24 -left-24 size-72 rounded-full bg-white/10 blur-3xl animate-blob" />
        <div className="pointer-events-none absolute -right-16 -bottom-32 size-96 rounded-full bg-white/10 blur-3xl animate-blob [animation-delay:3s]" />

        <div className="relative flex flex-col gap-10">
          <Image
            src="/pockettill-logo-white.png"
            alt="PocketTill"
            width={350}
            height={100}
            style={{ height: "auto" }}
            priority
            className="animate-fade-up"
          />
          <div className="flex flex-col gap-4 animate-fade-up [animation-delay:150ms]">
            <h2 className="max-w-md text-5xl leading-tight font-bold">DataMaster</h2>
            <p className="max-w-sm text-xl text-white/80">Built to make things happen.</p>
          </div>
        </div>
      </div>

      <div className="flex items-center justify-center p-6">
        <div className="w-full max-w-sm">
          <div className="mb-8">
            <h1 className="text-3xl font-semibold">Welcome Back</h1>
            <p className="mt-2 text-sm text-muted-foreground">
              Enter your email and password to access your account.
            </p>
          </div>
          <LoginForm />
        </div>
      </div>
    </div>
  );
}
