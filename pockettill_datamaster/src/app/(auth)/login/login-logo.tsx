"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { useTheme } from "next-themes";

export function LoginLogo() {
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  const src = mounted && resolvedTheme === "dark" ? "/pockettill-logo-white.png" : "/pockettill-logo.png";

  return (
    <Image
      key={src}
      src={src}
      alt="PocketTill"
      width={220}
      height={40}
      style={{ height: "auto" }}
      priority
    />
  );
}
