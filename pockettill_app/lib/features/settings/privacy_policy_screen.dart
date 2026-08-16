import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/legal_document.dart';
import '../../shared/widgets/pockettill_app_bar.dart';

/// Full Privacy Policy, linked from Settings and from the registration
/// screen's agreement checkbox.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Privacy Policy'),
      backgroundColor: AppTheme.background,
      body: const LegalDocument(
        title: 'PocketTill Privacy Policy',
        effectiveDate:
            'PocketTill (Pty) Ltd — Effective Date: 15 August 2026 | '
            'Last Updated: 15 August 2026',
        intro: [
          'PocketTill (Pty) Ltd respects your privacy and is committed to '
              'protecting personal information processed through our '
              'application, website and services.',
          'This Privacy Policy explains what information we collect, why '
              'we collect it, how we use it, how we protect it and the '
              'choices and rights available to you.',
          'PocketTill operates in South Africa and aims to process '
              'personal information in accordance with the Protection of '
              'Personal Information Act 4 of 2013 (POPIA) and other '
              'applicable laws.',
        ],
        sections: [
          LegalSection('1. Information We Collect', [
            LegalParagraph(
              "Depending on how you use PocketTill, we may collect and "
              'store information including:',
            ),
            LegalSubheading('1.1 Account Information'),
            LegalBullets([
              'Name or account identifier',
              'Phone number',
              'Email address, where provided',
              'Authentication information',
              'Shop name',
              'Information required to provide account support',
            ]),
            LegalSubheading('1.2 Shop and Business Information'),
            LegalBullets([
              'Shop name',
              'Sales records',
              'Sales history',
              'Product information',
              'Stock information',
              'Sales analytics and reports',
              'Business activity and performance information',
              'Other information necessary to provide shop-management '
                  'features',
            ]),
            LegalSubheading('1.3 Credit-Customer Information'),
            LegalParagraph(
              'PocketTill may allow shop owners to record information '
              'relating to customers who purchase goods on credit.',
            ),
            LegalParagraph(
              'This information may include information entered by the '
              'shop owner that is reasonably necessary to manage credit '
              'transactions and outstanding balances.',
            ),
            LegalParagraph(
              'The shop owner is responsible for ensuring that information '
              'relating to their customers is collected and used lawfully.',
            ),
            LegalParagraph(
              'Where PocketTill processes such information on behalf of a '
              'shop, PocketTill will process it only as reasonably '
              'necessary to provide and maintain the relevant PocketTill '
              'functionality, subject to applicable law and our '
              'contractual arrangements.',
            ),
            LegalSubheading('1.4 Technical Information'),
            LegalBullets([
              'Device information',
              'Application information',
              'Log information',
              'Authentication and security events',
              'Error reports',
              'Information relating to the performance and reliability of '
                  'the Service',
            ]),
          ]),
          LegalSection('2. Why We Use Your Information', [
            LegalBullets([
              'Creating and maintaining PocketTill accounts',
              'Authenticating users',
              'Providing the PocketTill service',
              'Recording and displaying shop transactions',
              'Providing sales, stock and business analytics',
              'Managing shop credit records',
              'Providing customer support',
              'Recovering accounts and verifying account ownership',
              'Preventing fraud, abuse and unauthorised access',
              'Maintaining and improving the security and reliability of '
                  'PocketTill',
              'Troubleshooting technical problems',
              "Improving PocketTill's features and user experience",
              'Complying with legal obligations',
              'Other purposes compatible with the purposes for which '
                  'information was collected or otherwise permitted by '
                  'applicable law',
            ]),
          ]),
          LegalSection('3. Account Recovery and Identity Verification', [
            LegalParagraph(
              'PocketTill may use information already stored in connection '
              'with your shop to help verify your identity and ownership '
              'of an account when you request account recovery or '
              'support.',
            ),
            LegalParagraph(
              'For this purpose, PocketTill may ask you to provide or '
              'confirm information such as your shop name, approximate or '
              'average sales activity, and information relating to your '
              'credit customers.',
            ),
            LegalParagraph(
              'This information is used to help determine whether the '
              'person requesting access is likely to be the legitimate '
              'account holder.',
            ),
            LegalParagraph(
              'This information is not used to publicly identify you or '
              'your shop.',
            ),
          ]),
          LegalSection('4. Crowdsourced Product Catalogue', [
            LegalParagraph(
              'PocketTill may operate a shared, crowdsourced product '
              'catalogue designed to help users quickly find and add '
              'products when recording sales or managing stock.',
            ),
            LegalParagraph(
              'Users may suggest or add product information that is not '
              'already available in the PocketTill catalogue. Information '
              "contributed to the shared catalogue may subsequently be "
              'made available to other PocketTill users.',
            ),
            LegalParagraph(
              'The shared catalogue may contain product name, category, '
              'brand, description, product identifiers where applicable, '
              'and other information necessary to identify or describe a '
              'product.',
            ),
            LegalParagraph(
              "Information contributed to the shared product catalogue is "
              "treated separately from a user's private shop records.",
            ),
            LegalParagraph(
              'A product added to the shared catalogue may be reused by '
              "other PocketTill users. PocketTill does not intend to make "
              "a contributing shop's private sales history, revenue, "
              'analytics, credit-customer information or other private '
              'shop information available to other users merely because '
              'that shop contributed a product.',
            ),
            LegalParagraph(
              'PocketTill may review, correct, standardise, merge or '
              'remove catalogue entries to maintain the quality and '
              'usefulness of the shared product catalogue.',
            ),
            LegalParagraph(
              'By contributing product information to the shared '
              'catalogue, you acknowledge that the product information '
              "may become part of PocketTill's shared catalogue and may "
              'be made available to other PocketTill users.',
            ),
          ]),
          LegalSection('5. Aggregated and Anonymised Data', [
            LegalParagraph(
              'PocketTill may analyse information generated through the '
              'platform to understand trends within the informal retail '
              'sector.',
            ),
            LegalParagraph(
              'In the future, PocketTill may use or provide aggregated or '
              'anonymised information relating to product demand, product '
              'categories, sales trends, general retail activity, shop '
              'performance trends, stock trends, regional or market-level '
              'trends, and other statistical information.',
            ),
            LegalParagraph(
              'Where information is described as aggregated or '
              'anonymised, PocketTill will take reasonable steps to '
              'ensure that it cannot reasonably be used to identify a '
              'particular shop, account holder or individual.',
            ),
            LegalParagraph(
              'PocketTill does not intend to sell or disclose identifiable '
              'individual customer records, individual credit-customer '
              'records, individual sales histories or other identifiable '
              'personal information as part of this aggregated-data '
              'activity.',
            ),
            LegalParagraph(
              'If a future use of personal information would constitute a '
              'new or incompatible purpose under applicable law, '
              'PocketTill will take the steps required by law before '
              'undertaking that processing.',
            ),
          ]),
          LegalSection('6. What We Do Not Do', [
            LegalParagraph('PocketTill does not intentionally:'),
            LegalBullets([
              'Sell identifiable personal information about individual '
                  'users to third parties for their own unrelated '
                  'purposes',
              'Sell identifiable credit-customer records',
              'Publicly publish individual shop sales histories',
              'Publicly publish individual customer credit records',
              'Use account-recovery information to publicly identify '
                  'users',
            ]),
          ]),
          LegalSection('7. Service Providers', [
            LegalParagraph(
              'PocketTill may use trusted third-party service providers '
              'to help operate the Service, including cloud hosting and '
              'databases, authentication, SMS or communication services, '
              'application infrastructure, security, error monitoring and '
              'analytics.',
            ),
            LegalParagraph(
              'Where third parties process personal information on '
              "PocketTill's behalf, we will take reasonable steps to "
              'ensure that appropriate contractual and security measures '
              'are in place.',
            ),
          ]),
          LegalSection('8. International Processing', [
            LegalParagraph(
              'Some third-party technology providers used by PocketTill '
              'may process or store information outside South Africa.',
            ),
            LegalParagraph(
              'Where personal information is transferred outside South '
              'Africa, PocketTill will take reasonable steps to ensure '
              'that the transfer is handled in accordance with applicable '
              'data-protection requirements.',
            ),
          ]),
          LegalSection('9. Security', [
            LegalParagraph(
              'PocketTill takes reasonable technical and organisational '
              'measures to protect personal information against '
              'unauthorised access, loss, destruction, unauthorised '
              'disclosure, alteration and other unlawful processing.',
            ),
            LegalParagraph(
              'These measures may include access controls, authentication '
              'mechanisms, secure infrastructure and other safeguards '
              'appropriate to the nature of the information being '
              'processed.',
            ),
            LegalParagraph(
              'However, no internet-connected service can guarantee '
              'absolute security.',
            ),
            LegalParagraph(
              'If PocketTill becomes aware of a security compromise '
              'involving personal information, we will respond in '
              'accordance with applicable legal requirements.',
            ),
          ]),
          LegalSection('10. Data Retention', [
            LegalParagraph(
              'PocketTill will retain personal information only for as '
              'long as reasonably necessary for the purposes for which it '
              'was collected, unless a longer retention period is '
              'required or permitted by law.',
            ),
            LegalParagraph(
              'We may retain certain information after an account is '
              'closed where reasonably necessary for legal compliance, '
              'accounting or record-keeping requirements, fraud '
              'prevention, security, dispute resolution, enforcement of '
              'agreements, or other legitimate purposes permitted by law.',
            ),
            LegalParagraph(
              'When information is no longer required, we will take '
              'reasonable steps to delete, destroy or anonymise it.',
            ),
          ]),
          LegalSection('11. Your Rights', [
            LegalParagraph(
              'Subject to applicable law, you may have rights to:',
            ),
            LegalBullets([
              'Request access to personal information that PocketTill '
                  'holds about you',
              'Request correction of inaccurate or incomplete information',
              'Request deletion of information where legally permitted',
              'Object to certain forms of processing',
              'Ask questions about how your information is being '
                  'processed',
              'Lodge a complaint regarding the handling of your personal '
                  'information',
            ]),
            LegalParagraph(
              'Some requests may be subject to legal limitations or '
              'verification requirements.',
            ),
          ]),
          LegalSection('12. Accuracy of Information', [
            LegalParagraph(
              'We rely on users to provide accurate information and to '
              'keep information reasonably up to date. If information '
              'associated with your account is inaccurate, you may '
              'request that it be corrected.',
            ),
          ]),
          LegalSection("13. Children's Information", [
            LegalParagraph(
              'PocketTill is intended for businesses and their authorised '
              'users and is not designed to knowingly collect personal '
              'information from children for independent use of the '
              'Service.',
            ),
            LegalParagraph(
              'If we become aware that we have collected personal '
              'information from a child in circumstances where such '
              'processing is not permitted by applicable law, we will '
              'take appropriate steps to address the situation.',
            ),
          ]),
          LegalSection('14. Direct Marketing', [
            LegalParagraph(
              'If PocketTill sends promotional communications, we will do '
              'so in accordance with applicable law.',
            ),
            LegalParagraph(
              'Where consent is required for electronic direct marketing, '
              'we will obtain the required consent and provide an '
              'appropriate means of opting out.',
            ),
          ]),
          LegalSection('15. Cookies and Similar Technologies', [
            LegalParagraph(
              'The PocketTill website may use cookies or similar '
              'technologies where necessary to operate the website, '
              'remember preferences, improve functionality, understand '
              'website usage or maintain security.',
            ),
            LegalParagraph(
              'Where required by law, we will provide appropriate '
              'information or obtain consent for non-essential '
              'technologies.',
            ),
          ]),
          LegalSection('16. Changes to This Privacy Policy', [
            LegalParagraph(
              'We may update this Privacy Policy as PocketTill develops '
              'or as legal and regulatory requirements change.',
            ),
            LegalParagraph(
              'If we make material changes to how we process personal '
              'information, we will take reasonable steps to notify '
              'users.',
            ),
            LegalParagraph(
              'The updated policy will display a revised Last Updated '
              'date.',
            ),
          ]),
          LegalSection('17. Complaints', [
            LegalParagraph(
              'If you believe that PocketTill has processed your personal '
              'information unlawfully or has otherwise interfered with '
              'your privacy rights, you may first contact PocketTill so '
              'that we can investigate and attempt to resolve the '
              'matter.',
            ),
            LegalParagraph(
              'You may also have the right to lodge a complaint with the '
              'Information Regulator of South Africa.',
            ),
          ]),
          LegalSection('18. Contact Us', [
            LegalParagraph('PocketTill (Pty) Ltd'),
            LegalParagraph('Website: https://pockettill.co.za'),
            LegalParagraph('Email: hello@pockettill.co.za'),
            LegalParagraph(
              'For privacy-related requests, please include enough '
              'information for us to identify the relevant PocketTill '
              'account and understand your request.',
            ),
          ]),
        ],
      ),
    );
  }
}
