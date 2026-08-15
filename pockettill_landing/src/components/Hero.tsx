import Image from "next/image";
import { ScanLine, WifiOff } from "lucide-react";
import { siteConfig } from "@/lib/site";

export default function Hero() {
  return (
    <section
      id="home"
      className="relative isolate flex flex-col justify-center overflow-hidden bg-white px-6 pb-10 pt-24 sm:min-h-screen sm:px-10 sm:pb-16 sm:pt-32"
    >
      <div className="mx-auto grid w-full max-w-6xl items-center gap-8 sm:gap-12 lg:grid-cols-2 lg:gap-10">
        <div className="order-2 text-center lg:order-1 lg:text-left">
          <h1 className="text-3xl font-black leading-[1.1] tracking-tight text-ink sm:text-5xl lg:text-[4rem] lg:leading-[1.05]">
            Run Your Shop.
            <br />
            All in Your Pocket.
          </h1>
          <p className="mx-auto mt-6 hidden max-w-md text-lg text-ink/60 sm:block lg:mx-0">
            PocketTill helps shop owners manage sales, stock and customer
            credit from one simple app.
          </p>

          <div className="mt-6 flex justify-center sm:mt-8 lg:justify-start">
            <a
              href={siteConfig.playStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2.5 rounded-xl bg-ink px-4 py-2.5 text-white shadow-lg shadow-ink/20 transition hover:bg-ink/90"
            >
              <Image
                src="/google-play-store-svgrepo-com.svg"
                alt=""
                width={18}
                height={18}
                unoptimized
                priority
                className="invert"
              />
              <span className="text-left leading-tight">
                <span className="block text-[10px] uppercase tracking-wide text-white/70">
                  Get it
                </span>
                <span className="block text-base font-bold">Google Play</span>
              </span>
            </a>
          </div>

          <p className="mt-4 text-sm text-ink/50 sm:mt-5">
            Built for South African informal retailers.
          </p>
        </div>

        <div className="relative order-1 mx-auto w-full max-w-[215px] sm:max-w-[260px] lg:order-2 lg:max-w-[340px]">
          <div
            aria-hidden
            className="pointer-events-none absolute left-1/2 top-1/2 -z-10 h-[95%] w-[150%] -translate-x-1/2 -translate-y-1/2 rounded-[50%] bg-brand/20 blur-[55px]"
          />

          <div className="rotate-3 drop-shadow-2xl transition-transform hover:rotate-1">
            <Image
              src="/pockettill_on_mobile.png"
              alt="PocketTill running on a phone"
              width={1024}
              height={1536}
              priority
              className="h-auto w-full"
            />
          </div>

          <div className="absolute -left-5 top-10 flex items-center gap-1.5 rounded-lg bg-white px-2.5 py-2 shadow-lg shadow-black/10 sm:-left-8 sm:top-16 sm:gap-2 sm:rounded-xl sm:px-3.5 sm:py-2.5">
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-brand/10 text-brand sm:h-8 sm:w-8">
              <ScanLine size={13} strokeWidth={2.25} className="sm:hidden" />
              <ScanLine
                size={16}
                strokeWidth={2.25}
                className="hidden sm:block"
              />
            </span>
            <span className="text-[11px] font-semibold text-ink sm:text-xs">
              Scan &amp; Sell
            </span>
          </div>

          <div className="absolute -right-4 bottom-14 flex items-center gap-1.5 rounded-lg bg-white px-2.5 py-2 shadow-lg shadow-black/10 sm:-right-6 sm:bottom-24 sm:gap-2 sm:rounded-xl sm:px-3.5 sm:py-2.5">
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-brand/10 text-brand sm:h-8 sm:w-8">
              <WifiOff size={13} strokeWidth={2.25} className="sm:hidden" />
              <WifiOff
                size={16}
                strokeWidth={2.25}
                className="hidden sm:block"
              />
            </span>
            <span className="text-[11px] font-semibold text-ink sm:text-xs">
              Works Offline
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}
