"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { useTheme } from "next-themes";

export function SidebarLogo() {
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  const fullLogoSrc =
    mounted && resolvedTheme === "dark" ? "/pockettill-logo-white.png" : "/pockettill-logo.png";

  return (
    <Link href="/" className="flex items-center">
      <Image
        src="/pockettill-icon.png"
        alt="PocketTill"
        width={28}
        height={28}
        className="hidden group-data-[collapsible=icon]:block"
      />
      <Image
        key={fullLogoSrc}
        src={fullLogoSrc}
        alt="PocketTill DataMaster"
        width={150}
        height={27}
        style={{ height: "auto" }}
        priority
        className="block group-data-[collapsible=icon]:hidden"
      />
    </Link>
  );
}
