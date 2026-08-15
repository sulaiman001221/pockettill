"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { siteConfig } from "@/lib/site";
import ContactModal from "./ContactModal";

const links = [
  { label: "Home", href: "#home" },
  { label: "Features", href: "#features" },
  { label: "Product", href: "#product" },
];

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [contactOpen, setContactOpen] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <>
      <header
        className={`fixed inset-x-0 top-0 z-50 border-b transition-all duration-300 ${
          scrolled
            ? "border-black/[0.08] bg-white/90 shadow-sm backdrop-blur-md"
            : "border-transparent bg-white/70 backdrop-blur-sm"
        }`}
      >
        <div className="px-6 sm:px-10">
          <nav
            className={`mx-auto flex max-w-6xl items-center justify-between transition-all duration-300 ${
              scrolled ? "py-4" : "py-5 sm:py-6"
            }`}
          >
            <a href="#home" className="shrink-0">
              <Image
                src="/pockettill_logo.png"
                alt={siteConfig.name}
                width={1000}
                height={190}
                className="h-7 w-auto sm:h-8"
                priority
              />
            </a>

            <div className="hidden items-center gap-8 md:flex">
              {links.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  className="text-sm font-medium text-ink/70 transition hover:text-ink"
                >
                  {link.label}
                </a>
              ))}
            </div>

            <div className="flex items-center gap-2 sm:gap-3">
              <button
                type="button"
                onClick={() => setContactOpen(true)}
                className="rounded-full bg-brand px-5 py-2.5 text-sm font-semibold text-white transition hover:bg-brand-dark sm:px-7 sm:py-3"
              >
                Contact
              </button>

              <button
                type="button"
                onClick={() => setMobileOpen((v) => !v)}
                aria-label={mobileOpen ? "Close menu" : "Open menu"}
                aria-expanded={mobileOpen}
                className="flex h-9 w-9 flex-col items-end justify-center gap-[6px] rounded-lg md:hidden"
              >
                <span
                  className={`block h-[2px] rounded-full bg-ink transition-all duration-300 ease-out ${
                    mobileOpen ? "w-6 translate-y-[4px] rotate-45" : "w-6"
                  }`}
                />
                <span
                  className={`block h-[2px] rounded-full bg-ink transition-all duration-300 ease-out ${
                    mobileOpen ? "w-6 -translate-y-[4px] -rotate-45" : "w-4"
                  }`}
                />
              </button>
            </div>
          </nav>
        </div>

        <div
          className={`grid overflow-hidden border-black/[0.06] transition-all duration-300 ease-out md:hidden ${
            mobileOpen
              ? "grid-rows-[1fr] border-t opacity-100"
              : "grid-rows-[0fr] opacity-0"
          }`}
        >
          <div className="min-h-0">
            <div className="mx-auto flex max-w-6xl flex-col gap-1 bg-white px-6 py-3">
              {links.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  onClick={() => setMobileOpen(false)}
                  className="rounded-lg px-2 py-2.5 text-sm font-medium text-ink/70 transition hover:bg-black/5 hover:text-ink"
                >
                  {link.label}
                </a>
              ))}
            </div>
          </div>
        </div>
      </header>

      <ContactModal open={contactOpen} onClose={() => setContactOpen(false)} />
    </>
  );
}
