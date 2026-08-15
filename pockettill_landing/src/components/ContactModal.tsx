"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { X, CheckCircle2 } from "lucide-react";
import { waLink } from "@/lib/site";
import { CONTACT_HINT, isValidContact } from "@/lib/validate";

export default function ContactModal({
  open,
  onClose,
}: {
  open: boolean;
  onClose: () => void;
}) {
  const [submitted, setSubmitted] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (sending) return;

    const form = event.currentTarget;
    const data = new FormData(form);

    const contactValue = String(data.get("contact") ?? "").trim();
    if (!isValidContact(contactValue)) {
      setError(CONTACT_HINT);
      form.querySelector<HTMLInputElement>("#contact-phone")?.focus();
      return;
    }

    setSending(true);
    setError(null);

    try {
      const response = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: data.get("name"),
          contact: data.get("contact"),
          message: data.get("message"),
          website: data.get("website"),
        }),
      });

      if (!response.ok) {
        const body = await response.json().catch(() => null);
        setError(body?.error ?? "Could not send your message. Please try again.");
        return;
      }

      form.reset();
      setSubmitted(true);
    } catch {
      setError("Could not reach us — please check your connection or use WhatsApp.");
    } finally {
      setSending(false);
    }
  }

  useEffect(() => {
    if (!open) return;

    document.body.style.overflow = "hidden";
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKeyDown);

    return () => {
      document.body.style.overflow = "";
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [open, onClose]);

  useEffect(() => {
    if (open) {
      setSubmitted(false);
      setError(null);
      setSending(false);
    }
  }, [open]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 px-4"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-md rounded-2xl bg-white p-6 shadow-2xl sm:p-8"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          aria-label="Close"
          className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full text-ink/50 transition hover:bg-black/5 hover:text-ink"
        >
          <X size={18} />
        </button>

        {submitted ? (
          <div className="flex flex-col items-center py-6 text-center">
            <CheckCircle2 size={40} className="text-brand" />
            <h2 className="mt-4 text-xl font-bold text-ink">
              Message sent
            </h2>
            <p className="mt-2 text-sm text-ink/60">
              Thanks for reaching out — we&apos;ll get back to you soon.
            </p>
          </div>
        ) : (
          <>
            <h2 className="text-xl font-bold text-ink">Get in touch</h2>
            <p className="mt-1.5 text-sm text-ink/60">
              Questions about PocketTill? Send us a message.
            </p>

            <form className="mt-6 space-y-4" onSubmit={handleSubmit} noValidate>
              {/* Honeypot — hidden from people, irresistible to bots. */}
              <div className="absolute left-[-9999px]" aria-hidden>
                <label htmlFor="contact-website">Website</label>
                <input
                  id="contact-website"
                  name="website"
                  type="text"
                  tabIndex={-1}
                  autoComplete="off"
                />
              </div>

              <div>
                <label
                  htmlFor="contact-name"
                  className="mb-1.5 block text-sm font-medium text-ink/80"
                >
                  Name
                </label>
                <input
                  id="contact-name"
                  name="name"
                  type="text"
                  required
                  className="w-full rounded-lg border border-black/10 px-3.5 py-2.5 text-sm text-ink outline-none transition focus:border-brand focus:ring-1 focus:ring-brand"
                  placeholder="Your name"
                />
              </div>

              <div>
                <label
                  htmlFor="contact-phone"
                  className="mb-1.5 block text-sm font-medium text-ink/80"
                >
                  Phone or email
                </label>
                <input
                  id="contact-phone"
                  name="contact"
                  type="text"
                  required
                  className="w-full rounded-lg border border-black/10 px-3.5 py-2.5 text-sm text-ink outline-none transition focus:border-brand focus:ring-1 focus:ring-brand"
                  placeholder="082 123 4567 or you@email.com"
                />
              </div>

              <div>
                <label
                  htmlFor="contact-message"
                  className="mb-1.5 block text-sm font-medium text-ink/80"
                >
                  Message
                </label>
                <textarea
                  id="contact-message"
                  name="message"
                  required
                  rows={4}
                  className="w-full resize-none rounded-lg border border-black/10 px-3.5 py-2.5 text-sm text-ink outline-none transition focus:border-brand focus:ring-1 focus:ring-brand"
                  placeholder="How can we help?"
                />
              </div>

              {error && (
                <p
                  role="alert"
                  className="rounded-lg bg-red-50 px-3.5 py-2.5 text-sm text-red-600"
                >
                  {error}
                </p>
              )}

              <button
                type="submit"
                disabled={sending}
                className="w-full rounded-full bg-brand py-3 text-sm font-semibold text-white transition hover:bg-brand-dark disabled:cursor-not-allowed disabled:opacity-60"
              >
                {sending ? "Sending…" : "Send message"}
              </button>
            </form>

            <div className="mt-5 flex items-center gap-3">
              <div className="h-px flex-1 bg-black/10" />
              <span className="text-xs text-ink/40">or</span>
              <div className="h-px flex-1 bg-black/10" />
            </div>

            <a
              href={waLink("Hi, I'd like to know more about PocketTill")}
              target="_blank"
              rel="noopener noreferrer"
              className="mt-5 flex w-full items-center justify-center gap-2 rounded-full border border-black/10 py-3 text-sm font-semibold text-ink transition hover:bg-black/5"
            >
              <Image
                src="/whatsapp-svgrepo-com.svg"
                alt=""
                width={18}
                height={18}
                unoptimized
              />
              Chat with us on WhatsApp
            </a>
          </>
        )}
      </div>
    </div>
  );
}
