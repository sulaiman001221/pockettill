import Image from "next/image";
import { siteConfig } from "@/lib/site";

export default function ComingSoon() {
  return (
    <section
      id="product"
      className="relative isolate overflow-hidden px-6 py-24 sm:px-10"
      style={{
        background:
          "linear-gradient(165deg, #F4F7FE 0%, #E9EEFB 45%, #DFE7F9 100%)",
      }}
    >
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-12 md:flex-row md:gap-16">
        <div className="relative w-full max-w-[270px] md:max-w-[360px]">
          <div
            aria-hidden
            className="absolute left-1/2 top-1/2 -z-10 h-[115%] w-[115%] -translate-x-1/2 -translate-y-1/2 rounded-full bg-white/70 blur-[60px]"
          />

          <Image
            src="/pockettill_sunmi.png"
            alt="PocketTill Terminal — dedicated POS hardware"
            width={1261}
            height={1247}
            className="h-auto w-full [filter:drop-shadow(0_28px_38px_rgba(38,58,135,0.28))]"
          />
        </div>

        <div className="max-w-xl text-center md:text-left">
          <span className="inline-flex items-center rounded-full bg-brand/10 px-3.5 py-1.5 text-xs font-bold uppercase tracking-wide text-brand">
            Coming Soon
          </span>

          <h2 className="mt-4 text-3xl font-black tracking-tight text-ink sm:text-4xl">
            PocketTill Terminal
          </h2>

          <p className="mt-4 text-ink/60">
            A dedicated POS terminal built for spaza shops. Purpose-built
            hardware running PocketTill, with a built-in barcode scanner and
            receipt printer.
          </p>

          <div className="mt-8 flex justify-center md:justify-start">
            <a
              href={siteConfig.whatsappUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2.5 rounded-full bg-white px-7 py-3.5 font-semibold text-ink shadow-lg shadow-[#26397f]/15 transition hover:shadow-xl"
            >
              <Image
                src="/whatsapp-svgrepo-com.svg"
                alt=""
                width={24}
                height={24}
                unoptimized
              />
              Join the waitlist
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}
