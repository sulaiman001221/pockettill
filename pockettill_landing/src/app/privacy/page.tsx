import type { Metadata } from "next";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import { LegalDocument, type LegalBlock } from "@/components/legal/LegalDocument";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How PocketTill collects, uses and protects personal information processed through our application, website and services.",
};

const blocks: LegalBlock[] = [
  { type: "heading", text: "Introduction" },
  {
    type: "p",
    text: "PocketTill (Pty) Ltd respects your privacy and is committed to protecting personal information processed through our application, website and services.",
  },
  {
    type: "p",
    text: "This Privacy Policy explains what information we collect, why we collect it, how we use it, how we protect it and the choices and rights available to you.",
  },
  {
    type: "p",
    text: "PocketTill operates in South Africa and aims to process personal information in accordance with the Protection of Personal Information Act 4 of 2013 (POPIA) and other applicable laws.",
  },

  { type: "heading", text: "1. Information We Collect" },
  {
    type: "p",
    text: "Depending on how you use PocketTill, we may collect and store information including:",
  },

  { type: "heading", text: "1.1 Account Information" },
  {
    type: "list",
    items: [
      "Name or account identifier;",
      "Phone number;",
      "Email address, where provided;",
      "Authentication information;",
      "Shop name; and",
      "Information required to provide account support.",
    ],
  },

  { type: "heading", text: "1.2 Shop and Business Information" },
  {
    type: "list",
    items: [
      "Shop name;",
      "Sales records;",
      "Sales history;",
      "Product information;",
      "Stock information;",
      "Sales analytics and reports;",
      "Business activity and performance information; and",
      "Other information necessary to provide shop-management features.",
    ],
  },

  { type: "heading", text: "1.3 Credit-Customer Information" },
  {
    type: "p",
    text: "PocketTill may allow shop owners to record information relating to customers who purchase goods on credit.",
  },
  {
    type: "p",
    text: "This information may include information entered by the shop owner that is reasonably necessary to manage credit transactions and outstanding balances.",
  },
  {
    type: "p",
    text: "The shop owner is responsible for ensuring that information relating to their customers is collected and used lawfully.",
  },
  {
    type: "p",
    text: "Where PocketTill processes such information on behalf of a shop, PocketTill will process it only as reasonably necessary to provide and maintain the relevant PocketTill functionality, subject to applicable law and our contractual arrangements.",
  },

  { type: "heading", text: "1.4 Technical Information" },
  {
    type: "list",
    items: [
      "Device information;",
      "Application information;",
      "Log information;",
      "Authentication and security events;",
      "Error reports; and",
      "Information relating to the performance and reliability of the Service.",
    ],
  },

  { type: "heading", text: "2. Why We Use Your Information" },
  {
    type: "list",
    items: [
      "Creating and maintaining PocketTill accounts;",
      "Authenticating users;",
      "Providing the PocketTill service;",
      "Recording and displaying shop transactions;",
      "Providing sales, stock and business analytics;",
      "Managing shop credit records;",
      "Providing customer support;",
      "Recovering accounts and verifying account ownership;",
      "Preventing fraud, abuse and unauthorised access;",
      "Maintaining and improving the security and reliability of PocketTill;",
      "Troubleshooting technical problems;",
      "Improving PocketTill's features and user experience;",
      "Complying with legal obligations; and",
      "Other purposes compatible with the purposes for which information was collected or otherwise permitted by applicable law.",
    ],
  },

  { type: "heading", text: "3. Account Recovery and Identity Verification" },
  {
    type: "p",
    text: "PocketTill may use information already stored in connection with your shop to help verify your identity and ownership of an account when you request account recovery or support.",
  },
  {
    type: "p",
    text: "For this purpose, PocketTill may ask you to provide or confirm information such as your shop name, approximate or average sales activity, and information relating to your credit customers.",
  },
  {
    type: "p",
    text: "This information is used to help determine whether the person requesting access is likely to be the legitimate account holder.",
  },
  {
    type: "p",
    text: "This information is not used to publicly identify you or your shop.",
  },

  { type: "heading", text: "4. Crowdsourced Product Catalogue" },
  {
    type: "p",
    text: "PocketTill may operate a shared, crowdsourced product catalogue designed to help users quickly find and add products when recording sales or managing stock.",
  },
  {
    type: "p",
    text: "Users may suggest or add product information that is not already available in the PocketTill catalogue. Information contributed to the shared catalogue may subsequently be made available to other PocketTill users.",
  },
  {
    type: "p",
    text: "The shared catalogue may contain product name, category, brand, description, product identifiers where applicable, and other information necessary to identify or describe a product.",
  },
  {
    type: "p",
    text: "Information contributed to the shared product catalogue is treated separately from a user's private shop records.",
  },
  {
    type: "p",
    text: "A product added to the shared catalogue may be reused by other PocketTill users. PocketTill does not intend to make a contributing shop's private sales history, revenue, analytics, credit-customer information or other private shop information available to other users merely because that shop contributed a product.",
  },
  {
    type: "p",
    text: "PocketTill may review, correct, standardise, merge or remove catalogue entries to maintain the quality and usefulness of the shared product catalogue.",
  },
  {
    type: "p",
    text: "By contributing product information to the shared catalogue, you acknowledge that the product information may become part of PocketTill's shared catalogue and may be made available to other PocketTill users.",
  },

  { type: "heading", text: "5. Aggregated and Anonymised Data" },
  {
    type: "p",
    text: "PocketTill may analyse information generated through the platform to understand trends within the informal retail sector.",
  },
  {
    type: "p",
    text: "In the future, PocketTill may use or provide aggregated or anonymised information relating to product demand, product categories, sales trends, general retail activity, shop performance trends, stock trends, regional or market-level trends, and other statistical information.",
  },
  {
    type: "p",
    text: "Where information is described as aggregated or anonymised, PocketTill will take reasonable steps to ensure that it cannot reasonably be used to identify a particular shop, account holder or individual.",
  },
  {
    type: "p",
    text: "PocketTill does not intend to sell or disclose identifiable individual customer records, individual credit-customer records, individual sales histories or other identifiable personal information as part of this aggregated-data activity.",
  },
  {
    type: "p",
    text: "If a future use of personal information would constitute a new or incompatible purpose under applicable law, PocketTill will take the steps required by law before undertaking that processing.",
  },

  { type: "heading", text: "6. What We Do Not Do" },
  { type: "p", text: "PocketTill does not intentionally:" },
  {
    type: "list",
    items: [
      "Sell identifiable personal information about individual users to third parties for their own unrelated purposes;",
      "Sell identifiable credit-customer records;",
      "Publicly publish individual shop sales histories;",
      "Publicly publish individual customer credit records; or",
      "Use account-recovery information to publicly identify users.",
    ],
  },

  { type: "heading", text: "7. Service Providers" },
  {
    type: "p",
    text: "PocketTill may use trusted third-party service providers to help operate the Service, including cloud hosting and databases, authentication, SMS or communication services, application infrastructure, security, error monitoring and analytics.",
  },
  {
    type: "p",
    text: "Where third parties process personal information on PocketTill's behalf, we will take reasonable steps to ensure that appropriate contractual and security measures are in place.",
  },

  { type: "heading", text: "8. International Processing" },
  {
    type: "p",
    text: "Some third-party technology providers used by PocketTill may process or store information outside South Africa.",
  },
  {
    type: "p",
    text: "Where personal information is transferred outside South Africa, PocketTill will take reasonable steps to ensure that the transfer is handled in accordance with applicable data-protection requirements.",
  },

  { type: "heading", text: "9. Security" },
  {
    type: "p",
    text: "PocketTill takes reasonable technical and organisational measures to protect personal information against unauthorised access, loss, destruction, unauthorised disclosure, alteration and other unlawful processing.",
  },
  {
    type: "p",
    text: "These measures may include access controls, authentication mechanisms, secure infrastructure and other safeguards appropriate to the nature of the information being processed.",
  },
  {
    type: "p",
    text: "However, no internet-connected service can guarantee absolute security.",
  },
  {
    type: "p",
    text: "If PocketTill becomes aware of a security compromise involving personal information, we will respond in accordance with applicable legal requirements.",
  },

  { type: "heading", text: "10. Data Retention" },
  {
    type: "p",
    text: "PocketTill will retain personal information only for as long as reasonably necessary for the purposes for which it was collected, unless a longer retention period is required or permitted by law.",
  },
  {
    type: "p",
    text: "We may retain certain information after an account is closed where reasonably necessary for legal compliance, accounting or record-keeping requirements, fraud prevention, security, dispute resolution, enforcement of agreements, or other legitimate purposes permitted by law.",
  },
  {
    type: "p",
    text: "When information is no longer required, we will take reasonable steps to delete, destroy or anonymise it.",
  },

  { type: "heading", text: "11. Your Rights" },
  {
    type: "p",
    text: "Subject to applicable law, you may have rights to:",
  },
  {
    type: "list",
    items: [
      "Request access to personal information that PocketTill holds about you;",
      "Request correction of inaccurate or incomplete information;",
      "Request deletion of information where legally permitted;",
      "Object to certain forms of processing;",
      "Ask questions about how your information is being processed; and",
      "Lodge a complaint regarding the handling of your personal information.",
    ],
  },
  {
    type: "p",
    text: "Some requests may be subject to legal limitations or verification requirements.",
  },

  { type: "heading", text: "12. Accuracy of Information" },
  {
    type: "p",
    text: "We rely on users to provide accurate information and to keep information reasonably up to date. If information associated with your account is inaccurate, you may request that it be corrected.",
  },

  { type: "heading", text: "13. Children's Information" },
  {
    type: "p",
    text: "PocketTill is intended for businesses and their authorised users and is not designed to knowingly collect personal information from children for independent use of the Service.",
  },
  {
    type: "p",
    text: "If we become aware that we have collected personal information from a child in circumstances where such processing is not permitted by applicable law, we will take appropriate steps to address the situation.",
  },

  { type: "heading", text: "14. Direct Marketing" },
  {
    type: "p",
    text: "If PocketTill sends promotional communications, we will do so in accordance with applicable law.",
  },
  {
    type: "p",
    text: "Where consent is required for electronic direct marketing, we will obtain the required consent and provide an appropriate means of opting out.",
  },

  { type: "heading", text: "15. Cookies and Similar Technologies" },
  {
    type: "p",
    text: "The PocketTill website may use cookies or similar technologies where necessary to operate the website, remember preferences, improve functionality, understand website usage or maintain security.",
  },
  {
    type: "p",
    text: "Where required by law, we will provide appropriate information or obtain consent for non-essential technologies.",
  },

  { type: "heading", text: "16. Changes to This Privacy Policy" },
  {
    type: "p",
    text: "We may update this Privacy Policy as PocketTill develops or as legal and regulatory requirements change.",
  },
  {
    type: "p",
    text: "If we make material changes to how we process personal information, we will take reasonable steps to notify users.",
  },
  {
    type: "p",
    text: "The updated policy will display a revised Last Updated date.",
  },

  { type: "heading", text: "17. Complaints" },
  {
    type: "p",
    text: "If you believe that PocketTill has processed your personal information unlawfully or has otherwise interfered with your privacy rights, you may first contact PocketTill so that we can investigate and attempt to resolve the matter.",
  },
  {
    type: "p",
    text: "You may also have the right to lodge a complaint with the Information Regulator of South Africa.",
  },

  { type: "heading", text: "18. Contact Us" },
  { type: "p", text: "PocketTill (Pty) Ltd" },
  { type: "p", text: "Website: https://pockettill.co.za" },
  { type: "p", text: "Email: hello@pockettill.co.za" },
  {
    type: "p",
    text: "For privacy-related requests, please include enough information for us to identify the relevant PocketTill account and understand your request.",
  },
];

export default function PrivacyPage() {
  return (
    <main>
      <Navbar />
      <LegalDocument
        title="Privacy Policy"
        effectiveDate="15 August 2026"
        lastUpdated="15 August 2026"
        blocks={blocks}
      />
      <Footer />
    </main>
  );
}
