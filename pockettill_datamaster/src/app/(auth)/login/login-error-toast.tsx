"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect } from "react";
import { toast } from "sonner";

export function LoginErrorToast() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    const error = searchParams.get("error");

    if (error === "link_expired") {
      toast.error("That link has expired or was already used. Request a new one.");
      router.replace(pathname);
    } else if (error === "invite_expired") {
      toast.error(
        "Your invite link has expired or was already used. Ask an admin to send you a new invite from Admin Accounts."
      );
      router.replace(pathname);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchParams]);

  return null;
}
