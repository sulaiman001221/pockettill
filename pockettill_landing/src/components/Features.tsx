"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import {
  ScanLine,
  WifiOff,
  Package,
  CreditCard,
  BarChart3,
  FileText,
  type LucideIcon,
} from "lucide-react";

type Feature = {
  icon: LucideIcon;
  title: string;
  description: string;
};

const features: Feature[] = [
  {
    icon: ScanLine,
    title: "Scan & Sell",
    description: "Scan barcodes or search products, checkout in seconds.",
  },
  {
    icon: WifiOff,
    title: "Works Offline",
    description:
      "No internet? No problem. Everything syncs when you're back online.",
  },
  {
    icon: Package,
    title: "Stock Management",
    description: "Track inventory, get low stock alerts before you run out.",
  },
  {
    icon: CreditCard,
    title: "Credit Tracking",
    description: "Manage customer credit and repayments in one place.",
  },
  {
    icon: BarChart3,
    title: "Sales History",
    description: "See daily, weekly and monthly performance at a glance.",
  },
  {
    icon: FileText,
    title: "End of Day Summary",
    description: "Print your daily report with one tap.",
  },
];

const PAGE_SIZE = 3;
const STEP_MS = 2600;

const CIRCLE_IDLE = "#99acff";
const CIRCLE_ACTIVE = "#5170ff";

function usePrefersReducedMotion() {
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);

  return reduced;
}

export default function Features() {
  const [active, setActive] = useState(0);
  const [paused, setPaused] = useState(false);
  const reduced = usePrefersReducedMotion();

  useEffect(() => {
    if (paused || reduced) return;
    const timer = setTimeout(
      () => setActive((i) => (i + 1) % features.length),
      STEP_MS,
    );
    return () => clearTimeout(timer);
  }, [active, paused, reduced]);

  const page = Math.floor(active / PAGE_SIZE);
  const visible = features.slice(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE);

  return (
    <section id="features" className="bg-white px-6 pb-16 pt-8 sm:px-10 sm:pb-24 sm:pt-20">
      <div
        className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-2 lg:gap-16"
        onMouseEnter={() => setPaused(true)}
        onMouseLeave={() => setPaused(false)}
        onFocusCapture={() => setPaused(true)}
        onBlurCapture={() => setPaused(false)}
      >
        <div className="order-2 lg:order-1">
          <h2 className="max-w-md text-4xl font-black leading-[1.1] tracking-tight text-ink sm:text-5xl">
            Everything a <span className="text-brand">spaza shop</span> needs
          </h2>

          <ul
            key={page}
            className="mt-6 min-h-[17.75rem] space-y-1"
            style={
              reduced
                ? undefined
                : { animation: "featurePageIn 500ms ease-out both" }
            }
          >
            {visible.map((feature, i) => {
              const index = page * PAGE_SIZE + i;
              const isActive = index === active;
              const Icon = feature.icon;

              return (
                <li key={feature.title}>
                  <button
                    type="button"
                    onClick={() => setActive(index)}
                    aria-current={isActive}
                    className="flex w-full items-start gap-4 rounded-2xl p-3.5 text-left sm:p-4"
                  >
                    <span
                      className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full text-white transition-colors duration-300"
                      style={{
                        backgroundColor: isActive
                          ? CIRCLE_ACTIVE
                          : CIRCLE_IDLE,
                      }}
                    >
                      <Icon size={19} strokeWidth={2.25} />
                    </span>

                    <span className="min-w-0 flex-1">
                      <span className="block text-[1.0625rem] font-bold text-ink">
                        {feature.title}
                      </span>
                      <span className="mt-1 block text-sm leading-relaxed text-ink/60">
                        {feature.description}
                      </span>
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>

          <div className="mt-2 flex items-center gap-2.5 px-3.5 sm:px-4">
            {Array.from({ length: Math.ceil(features.length / PAGE_SIZE) }).map(
              (_, p) => {
                const isCurrent = p === page;
                const from = p * PAGE_SIZE + 1;
                const to = Math.min((p + 1) * PAGE_SIZE, features.length);

                return (
                  <button
                    key={p}
                    type="button"
                    onClick={() => setActive(p * PAGE_SIZE)}
                    aria-label={`Show features ${from} to ${to}`}
                    aria-current={isCurrent}
                    className="h-2 rounded-full transition-all duration-300"
                    style={{
                      width: isCurrent ? 30 : 10,
                      backgroundColor: isCurrent ? CIRCLE_ACTIVE : CIRCLE_IDLE,
                    }}
                  />
                );
              },
            )}
          </div>
        </div>

        <div className="order-1 lg:order-2">
          <Image
            src="/pockettill_features_nobg.png"
            alt="A shop owner using PocketTill to grow their business"
            width={1536}
            height={1024}
            priority
            className="h-auto w-full"
          />
        </div>
      </div>
    </section>
  );
}
