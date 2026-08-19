import Link from "next/link";

export type LegalBlock =
  | { type: "heading"; text: string }
  | { type: "p"; text: string }
  | { type: "list"; items: string[] };

export function LegalDocument({
  title,
  effectiveDate,
  lastUpdated,
  blocks,
}: {
  title: string;
  effectiveDate: string;
  lastUpdated: string;
  blocks: LegalBlock[];
}) {
  return (
    <article className="mx-auto max-w-3xl px-6 py-20 sm:px-10 sm:py-28">
      <Link
        href="/"
        className="text-sm font-medium text-brand transition hover:text-brand-dark"
      >
        &larr; Back to home
      </Link>

      <h1 className="mt-6 text-3xl font-black tracking-tight text-ink sm:text-4xl">
        {title}
      </h1>
      <p className="mt-3 text-sm text-ink/50">
        PocketTill (Pty) Ltd &middot; Effective Date: {effectiveDate} &middot;
        Last Updated: {lastUpdated}
      </p>

      <div className="mt-10 space-y-5">
        {blocks.map((block, i) => {
          if (block.type === "heading") {
            return (
              <h2
                key={i}
                className="!mt-12 text-xl font-bold text-ink first:!mt-0"
              >
                {block.text}
              </h2>
            );
          }
          if (block.type === "list") {
            return (
              <ul key={i} className="list-disc space-y-2 pl-5">
                {block.items.map((item, j) => (
                  <li key={j} className="leading-relaxed text-ink/70">
                    {item}
                  </li>
                ))}
              </ul>
            );
          }
          return (
            <p key={i} className="leading-relaxed text-ink/70">
              {block.text}
            </p>
          );
        })}
      </div>
    </article>
  );
}
