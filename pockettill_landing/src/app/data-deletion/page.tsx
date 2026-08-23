import type { Metadata } from "next";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { LegalDocument, type LegalBlock } from "@/components/legal/LegalDocument";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Delete Your Account & Data",
  description:
    "How to request deletion of your PocketTill account and data, and what is deleted, retained, and for how long.",
};

const blocks: LegalBlock[] = [
  {
    type: "p",
    text: "This page explains how to request deletion of your PocketTill account and the personal information associated with it, and what happens to your data once you do.",
  },

  { type: "heading", text: "How to Request Deletion" },
  {
    type: "p",
    text: "PocketTill does not yet offer in-app self-service account deletion. To request deletion of your account and data, contact us using either method below:",
  },
  {
    type: "list",
    items: [
      `Email ${siteConfig.email} with the subject line "Delete My Account"`,
      `WhatsApp us at +${siteConfig.whatsappNumber}`,
    ],
  },
  {
    type: "p",
    text: "Please include your shop name and the phone number registered to your PocketTill account, so we can verify you're the account holder before deleting anything. We will confirm your request and complete deletion within 30 days.",
  },

  { type: "heading", text: "What Gets Deleted" },
  {
    type: "list",
    items: [
      "Your account credentials and login information;",
      "Your shop profile (shop name, phone number, email address);",
      "Product and stock records;",
      "Sales records and sales history;",
      "Credit-customer records and credit transaction history;",
      "Analytics and reports generated from your shop's activity; and",
      "Any other information tied directly to your account.",
    ],
  },

  { type: "heading", text: "What May Be Retained, and for How Long" },
  {
    type: "p",
    text: "A small amount of information may be kept after deletion, only where necessary:",
  },
  {
    type: "list",
    items: [
      "Aggregated or anonymised information that can no longer be linked back to you or your shop (e.g. statistics about overall retail trends) may be retained indefinitely;",
      "Information PocketTill is required to keep to comply with legal, tax, accounting, fraud-prevention or dispute-resolution obligations will be retained only for as long as that legal requirement applies, then deleted; and",
      "Product entries you contributed to PocketTill's shared product catalogue may remain in the catalogue for other shops to use, since this information is not tied to your identity once contributed.",
    ],
  },
  {
    type: "p",
    text: "Outside of these cases, your data is permanently deleted and cannot be recovered once your request is processed.",
  },
  {
    type: "p",
    text: "For more detail on how we handle personal information generally, see our Privacy Policy.",
  },
];

export default function DataDeletionPage() {
  return (
    <main>
      <Navbar />
      <LegalDocument
        title="Delete Your PocketTill Account & Data"
        effectiveDate="23 August 2026"
        lastUpdated="23 August 2026"
        blocks={blocks}
      />
      <Footer />
    </main>
  );
}
