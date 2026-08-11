"use client";

import { useState } from "react";
import { useFormState, useFormStatus } from "react-dom";

import { requestPasswordReset, type RequestResetState } from "@/lib/actions/auth";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <Button type="submit" className="w-full" disabled={pending}>
      {pending ? "Sending…" : "Send reset link"}
    </Button>
  );
}

function ForgotPasswordFormBody() {
  const [state, formAction] = useFormState<RequestResetState, FormData>(
    requestPasswordReset,
    undefined
  );

  if (state?.success) {
    return (
      <p className="px-4 text-sm text-muted-foreground">
        If that email belongs to an admin account, a reset link is on its way. Check your inbox.
      </p>
    );
  }

  return (
    <form action={formAction} className="flex flex-col gap-4 px-4">
      <div className="grid gap-2">
        <Label htmlFor="reset-email">Email</Label>
        <Input
          id="reset-email"
          name="email"
          type="email"
          placeholder="you@pockettill.co.za"
          autoComplete="email"
          required
        />
      </div>
      {state?.error ? <p className="text-sm text-destructive">{state.error}</p> : null}
      <DialogFooter>
        <SubmitButton />
      </DialogFooter>
    </form>
  );
}

export function ForgotPasswordDialog() {
  const [open, setOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger
        render={
          <button type="button" className="text-sm font-medium text-primary hover:underline" />
        }
      >
        Forgot Your Password?
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Reset your password</DialogTitle>
          <DialogDescription>
            Enter your admin email and we&apos;ll send you a link to reset your password.
          </DialogDescription>
        </DialogHeader>

        {/* Only mounted while open, so useFormState resets fresh each time
            the dialog reopens instead of showing a stale success message. */}
        {open ? <ForgotPasswordFormBody /> : null}
      </DialogContent>
    </Dialog>
  );
}
