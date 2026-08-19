import type { Metadata } from "next";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { LegalDocument, type LegalBlock } from "@/components/legal/LegalDocument";

export const metadata: Metadata = {
  title: "Terms of Use",
  description:
    "The terms that govern your access to and use of the PocketTill application, website, software and services.",
};

const blocks: LegalBlock[] = [
  { type: "heading", text: "Introduction" },
  {
    type: "p",
    text: 'Welcome to PocketTill. These Terms of Use ("Terms") govern your access to and use of the PocketTill application, website, software, services and related products ("PocketTill", "Service", "we", "us" or "our").',
  },
  {
    type: "p",
    text: "By creating an account or using PocketTill, you agree to these Terms. If you do not agree with these Terms, you should not use the Service.",
  },

  { type: "heading", text: "1. About PocketTill" },
  {
    type: "p",
    text: "PocketTill is a point-of-sale and shop-management platform designed primarily for informal retailers, including spaza shops and small retail businesses.",
  },
  { type: "p", text: "PocketTill may provide features including:" },
  {
    type: "list",
    items: [
      "Recording and managing sales;",
      "Managing products and stock;",
      "Recording and managing customer credit;",
      "Viewing sales history;",
      "Viewing business analytics and reports;",
      "Searching for products;",
      "Requesting products to be added to the PocketTill product database; and",
      "Other features that we may introduce from time to time.",
    ],
  },
  {
    type: "p",
    text: "We may modify, improve, add or remove features from the Service as PocketTill develops.",
  },

  { type: "heading", text: "2. Eligibility and Account Registration" },
  {
    type: "p",
    text: "To use PocketTill, you must provide information that is reasonably required to create and maintain your account.",
  },
  {
    type: "p",
    text: "You agree that the information you provide should be accurate and kept reasonably up to date.",
  },
  {
    type: "p",
    text: "You are responsible for maintaining the confidentiality of your account credentials, taking reasonable steps to prevent unauthorised access, ensuring information entered into PocketTill is accurate, and not allowing another person to use your account in a manner that compromises its security.",
  },
  {
    type: "p",
    text: "You must notify PocketTill if you believe that your account has been accessed without your permission.",
  },

  { type: "heading", text: "3. Your Shop Data" },
  {
    type: "p",
    text: "PocketTill allows you to enter and store information relating to your shop.",
  },
  { type: "p", text: "This may include:" },
  {
    type: "list",
    items: [
      "Shop name;",
      "Sales records and sales history;",
      "Product and stock information;",
      "Business analytics;",
      "Credit-customer information; and",
      "Other information that you choose to enter into the Service.",
    ],
  },
  {
    type: "p",
    text: "You retain your rights in the business information that you provide to PocketTill. You grant PocketTill the limited rights necessary to store, process, display and otherwise use this information to provide, maintain, secure and improve the Service.",
  },

  { type: "heading", text: "4. Credit-Customer Information" },
  {
    type: "p",
    text: "PocketTill may allow you to record information about customers who purchase goods on credit.",
  },
  {
    type: "p",
    text: "You are responsible for ensuring that you have a lawful basis for collecting and entering personal information about your customers into PocketTill.",
  },
  {
    type: "p",
    text: "You should only enter information that is reasonably necessary for managing your shop's credit activities.",
  },
  {
    type: "p",
    text: "PocketTill does not take ownership of the relationship between you and your credit customers. PocketTill provides software to help you manage that information.",
  },

  { type: "heading", text: "5. Account Recovery and Verification" },
  {
    type: "p",
    text: "If you lose access to your PocketTill account or request assistance recovering your account, PocketTill may use information already associated with your shop to help verify that you are the legitimate account holder.",
  },
  {
    type: "p",
    text: "Depending on the circumstances, verification may include asking you questions about information associated with your shop, which may include your shop name, approximate or average sales activity, and information relating to your recorded credit customers.",
  },
  {
    type: "p",
    text: "The purpose of this process is to help protect accounts against unauthorised access. PocketTill does not guarantee that account recovery will always be possible.",
  },

  { type: "heading", text: "6. Crowdsourced Product Catalogue" },
  {
    type: "p",
    text: "PocketTill may allow users to contribute product information to a shared product catalogue.",
  },
  {
    type: "p",
    text: "By submitting product information to the shared catalogue, you grant PocketTill permission to store, use, modify, standardise, organise and make that product information available to other PocketTill users as part of the Service.",
  },
  {
    type: "p",
    text: "You should only submit product information that you have the right to provide.",
  },
  {
    type: "p",
    text: "The shared catalogue is intended to contain general product information and does not include a user's private shop records merely because that user contributed a product.",
  },
  {
    type: "p",
    text: "PocketTill may modify, merge, remove or correct catalogue entries where reasonably necessary to maintain the accuracy and quality of the catalogue.",
  },
  {
    type: "p",
    text: "PocketTill may also use aggregated information from the product catalogue to improve its product database, analytics and services.",
  },

  { type: "heading", text: "7. Acceptable Use" },
  { type: "p", text: "You agree not to:" },
  {
    type: "list",
    items: [
      "Use PocketTill for unlawful purposes;",
      "Attempt to gain unauthorised access to another user's account;",
      "Attempt to interfere with or disrupt the Service;",
      "Reverse engineer, decompile or otherwise attempt to extract the underlying source code of PocketTill, except where permitted by applicable law;",
      "Upload malicious software or other harmful material;",
      "Use PocketTill to violate another person's privacy or legal rights;",
      "Enter information that you do not have the right or lawful basis to process; or",
      "Use the Service in a way that could damage PocketTill, its users or its systems.",
    ],
  },

  { type: "heading", text: "8. Accuracy of Information" },
  {
    type: "p",
    text: "PocketTill provides tools for recording and analysing business information. You are responsible for reviewing the information you enter and ensuring that your business records are accurate.",
  },
  {
    type: "p",
    text: "PocketTill does not guarantee that analytics, reports or other calculations will always be free from errors, particularly where information entered by the user is incomplete or incorrect.",
  },
  {
    type: "p",
    text: "PocketTill should not be treated as a substitute for professional accounting, tax, legal or financial advice.",
  },

  { type: "heading", text: "9. Availability of the Service" },
  {
    type: "p",
    text: "We aim to keep PocketTill available and reliable, but we do not guarantee that the Service will always be available without interruption.",
  },
  {
    type: "p",
    text: "The Service may occasionally be unavailable because of maintenance, software updates, technical problems, internet or network failures, third-party service interruptions, security incidents, or circumstances outside our reasonable control.",
  },
  {
    type: "p",
    text: "We may temporarily restrict access where reasonably necessary to protect PocketTill, its users or our systems.",
  },

  { type: "heading", text: "10. Third-Party Services" },
  {
    type: "p",
    text: "PocketTill may rely on third-party providers to operate certain parts of the Service, including infrastructure, authentication, communications, hosting, analytics or other technical services.",
  },
  {
    type: "p",
    text: "These providers may process information on PocketTill's behalf where necessary to provide their services.",
  },
  {
    type: "p",
    text: "PocketTill will take reasonable steps to use appropriate providers and protect information processed through such services.",
  },

  { type: "heading", text: "11. Data and Privacy" },
  {
    type: "p",
    text: "Your use of PocketTill is also governed by our Privacy Policy. The Privacy Policy explains what information we collect, why we collect it, how we use it, how we protect it and the rights available to data subjects.",
  },

  { type: "heading", text: "12. Aggregated and Anonymised Information" },
  {
    type: "p",
    text: "PocketTill may analyse information generated through the Service to understand general trends and improve its products and services.",
  },
  {
    type: "p",
    text: "Where legally permitted, PocketTill may create aggregated or anonymised information relating to retail trends, product categories, sales patterns, shop activity, stock trends, general business performance and other statistical information.",
  },
  {
    type: "p",
    text: "PocketTill will not intentionally use aggregated or anonymised information to identify a particular shop or individual.",
  },
  {
    type: "p",
    text: "If PocketTill proposes to use personal information for a new purpose that is not compatible with the purpose for which the information was originally collected, PocketTill will take any steps required by applicable law before doing so.",
  },

  { type: "heading", text: "13. Intellectual Property" },
  {
    type: "p",
    text: "PocketTill and its software, branding, designs, logos, interfaces, content and technology are owned by or licensed to PocketTill and are protected by applicable intellectual property laws.",
  },
  {
    type: "p",
    text: "These Terms do not transfer ownership of PocketTill's intellectual property to you.",
  },

  { type: "heading", text: "14. Feedback" },
  {
    type: "p",
    text: "If you provide suggestions, ideas or feedback regarding PocketTill, you agree that PocketTill may use that feedback to improve the Service without owing you compensation, provided that doing so does not disclose your confidential personal or business information.",
  },

  { type: "heading", text: "15. Suspension and Termination" },
  { type: "p", text: "You may stop using PocketTill at any time." },
  {
    type: "p",
    text: "PocketTill may suspend or terminate an account where reasonably necessary, including where the user materially breaches these Terms, the account is used unlawfully, the account creates a security risk, the user attempts to abuse or compromise the Service, or continued access would expose PocketTill or another user to significant risk.",
  },
  {
    type: "p",
    text: "Where reasonably possible, PocketTill will provide notice before terminating an account unless immediate action is required for security, legal or operational reasons.",
  },

  { type: "heading", text: "16. Data After Account Termination" },
  {
    type: "p",
    text: "When an account is closed, PocketTill may retain certain information for as long as reasonably necessary to comply with legal obligations, resolve disputes, prevent fraud or abuse, maintain security, or fulfil other legitimate purposes permitted by applicable law.",
  },
  {
    type: "p",
    text: "Information that is no longer required will be deleted, destroyed or anonymised in accordance with our retention practices and applicable law.",
  },

  { type: "heading", text: "17. Disclaimers" },
  {
    type: "p",
    text: "PocketTill is provided as a software service to assist with shop management.",
  },
  {
    type: "p",
    text: "To the extent permitted by applicable law, PocketTill does not guarantee that the Service will always be uninterrupted, completely error-free, that business results will improve as a result of using PocketTill, or that information entered by users will be accurate.",
  },
  {
    type: "p",
    text: "Nothing in these Terms excludes or limits any right or protection that cannot lawfully be excluded or limited under South African law.",
  },

  { type: "heading", text: "18. Limitation of Liability" },
  {
    type: "p",
    text: "To the maximum extent permitted by law, PocketTill will not be responsible for indirect, incidental, special or consequential losses arising from the use of the Service, including loss of profits, business interruption or loss of anticipated business opportunities.",
  },
  {
    type: "p",
    text: "Nothing in these Terms limits liability where such limitation is prohibited by applicable law.",
  },

  { type: "heading", text: "19. Changes to These Terms" },
  {
    type: "p",
    text: "We may update these Terms from time to time. When we make material changes, we will take reasonable steps to notify users, such as displaying a notice within the Service or updating the date shown at the beginning of these Terms.",
  },
  {
    type: "p",
    text: "Your continued use of PocketTill after updated Terms become effective constitutes acceptance of the updated Terms, to the extent permitted by law.",
  },

  { type: "heading", text: "20. Governing Law" },
  {
    type: "p",
    text: "These Terms are governed by the laws of the Republic of South Africa. Any dispute relating to these Terms will be subject to the applicable courts and dispute-resolution mechanisms of South Africa.",
  },

  { type: "heading", text: "21. Contact" },
  { type: "p", text: "PocketTill (Pty) Ltd" },
  { type: "p", text: "Website: https://pockettill.co.za" },
  { type: "p", text: "Email: hello@pockettill.co.za" },
];

export default function TermsPage() {
  return (
    <main>
      <Navbar />
      <LegalDocument
        title="Terms of Use"
        effectiveDate="15 August 2026"
        lastUpdated="15 August 2026"
        blocks={blocks}
      />
      <Footer />
    </main>
  );
}
