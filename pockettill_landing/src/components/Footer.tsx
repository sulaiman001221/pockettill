import Image from "next/image";
import Link from "next/link";
import { siteConfig } from "@/lib/site";

function FacebookIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
      <path d="M22 12.06C22 6.5 17.52 2 12 2S2 6.5 2 12.06c0 5 3.66 9.15 8.44 9.94v-7.03H7.9v-2.91h2.54V9.85c0-2.51 1.49-3.9 3.77-3.9 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.63.77-1.63 1.56v1.89h2.78l-.44 2.91h-2.34V22c4.78-.79 8.44-4.94 8.44-9.94Z" />
    </svg>
  );
}

function LinkedinIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
      <path d="M20.45 20.45h-3.55v-5.57c0-1.33-.02-3.04-1.85-3.04-1.85 0-2.14 1.45-2.14 2.94v5.67H9.36V9h3.41v1.56h.05c.47-.9 1.63-1.85 3.36-1.85 3.6 0 4.27 2.37 4.27 5.45v6.29ZM5.34 7.43a2.06 2.06 0 1 1 0-4.12 2.06 2.06 0 0 1 0 4.12ZM7.12 20.45H3.56V9h3.56v11.45Z" />
    </svg>
  );
}

export default function Footer() {
  return (
    <footer className="bg-black px-6 py-16 text-white sm:px-10">
      <div className="mx-auto grid max-w-6xl gap-12 md:grid-cols-3">
        <div>
          <Image
            src="/pockettill_logo_white.png"
            alt={siteConfig.name}
            width={1000}
            height={180}
            className="h-8 w-auto"
          />
          <p className="mt-4 text-sm font-medium text-white/80">
            The POS app built for South African spaza shops
          </p>
          <p className="mt-3 text-sm leading-relaxed text-white/55">
            PocketTill was born from a simple idea — give South African
            spaza shop owners the tools that big retailers take for granted.
            Built in Johannesburg, for the township economy.
          </p>
        </div>

        <div>
          <h3 className="text-sm font-semibold uppercase tracking-wide text-white/50">
            Quick Links
          </h3>
          <ul className="mt-4 space-y-2.5 text-sm text-white/75">
            <li>
              <a href="#features" className="hover:text-white">
                Features
              </a>
            </li>
            <li>
              <a href="#product" className="hover:text-white">
                Coming Soon
              </a>
            </li>
            <li>
              <Link href="/privacy" className="hover:text-white">
                Privacy Policy
              </Link>
            </li>
            <li>
              <Link href="/terms" className="hover:text-white">
                Terms of Service
              </Link>
            </li>
          </ul>
        </div>

        <div>
          <h3 className="text-sm font-semibold uppercase tracking-wide text-white/50">
            Connect
          </h3>
          <div className="mt-4 flex items-center gap-3">
            <a
              href={siteConfig.facebookUrl}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="Facebook"
              className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 transition hover:bg-white/20"
            >
              <FacebookIcon />
            </a>
            <a
              href={siteConfig.linkedinUrl}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="LinkedIn"
              className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 transition hover:bg-white/20"
            >
              <LinkedinIcon />
            </a>
            <a
              href={siteConfig.whatsappUrl}
              target="_blank"
              rel="noopener noreferrer"
              aria-label="WhatsApp"
              className="flex h-10 w-10 items-center justify-center overflow-hidden rounded-full bg-white/10 transition hover:bg-white/20"
            >
              <Image
                src="/black-whatsapp-svgrepo-com.svg"
                alt=""
                width={18}
                height={18}
                unoptimized
                className="invert"
              />
            </a>
          </div>

          <a
            href={siteConfig.playStoreUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="mt-6 inline-flex items-center gap-3 rounded-xl border border-white/25 bg-black px-4 py-2.5 transition hover:border-white/50"
          >
            <Image
              src="/google-play-store-colorful-logo-svgrepo-com.svg"
              alt=""
              width={22}
              height={22}
              unoptimized
            />
            <span className="text-left leading-tight text-white">
              <span className="block text-[10px] uppercase tracking-wide">
                Get it on
              </span>
              <span className="block text-base font-semibold">
                Google Play
              </span>
            </span>
          </a>
        </div>
      </div>

      <div className="mx-auto mt-12 max-w-6xl border-t border-white/10 pt-6 text-center text-xs text-white/40">
        © 2026 PocketTill. All rights reserved. Built in Johannesburg 🇿🇦
      </div>
    </footer>
  );
}
