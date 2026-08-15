import Image from "next/image";
import { Check } from "lucide-react";

const bullets = [
  "Spaza shop owners managing stock manually",
  "Tuck shops running credit for loyal customers",
  "Informal retailers ready to grow their business",
  "Any small shop that needs a simple, reliable POS",
];

export default function WhoItsFor() {
  return (
    <section className="bg-white px-6 py-20 sm:px-10">
      <div className="mx-auto max-w-6xl rounded-[2rem] bg-ink px-6 py-14 text-white sm:px-12 sm:py-16">
        <h2 className="text-center text-3xl font-extrabold tracking-tight sm:text-4xl">
          Built for the heartbeat of South African townships
        </h2>

        <div className="mt-12 grid gap-10 md:grid-cols-2 md:items-center md:gap-14">
          <div className="overflow-hidden rounded-2xl">
            <Image
              src="/spaza-shop-red.webp"
              alt="A South African spaza shop"
              width={823}
              height={549}
              className="h-auto w-full object-cover"
            />
          </div>

          <div>
            <ul className="space-y-4">
              {bullets.map((bullet) => (
                <li key={bullet} className="flex items-start gap-3">
                  <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand/20 text-brand-light">
                    <Check size={15} strokeWidth={3} />
                  </span>
                  <span className="text-white/85">{bullet}</span>
                </li>
              ))}
            </ul>

            <p className="mt-8 rounded-xl border border-brand/30 bg-brand/10 px-5 py-4 text-sm text-white/85">
              Join our founding stores programme — first 100 stores get a
              special lifetime offer.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
