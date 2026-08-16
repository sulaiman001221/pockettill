import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/legal_document.dart';
import '../../shared/widgets/pockettill_app_bar.dart';

/// Full Terms of Use, linked from Settings and from the registration
/// screen's agreement checkbox.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showMenuIcon: false,
        title: 'Terms of Use',
      ),
      backgroundColor: AppTheme.background,
      body: const LegalDocument(
        title: 'PocketTill Terms of Use',
        effectiveDate:
            'PocketTill (Pty) Ltd — Effective Date: 15 August 2026 | '
            'Last Updated: 15 August 2026',
        intro: [
          'Welcome to PocketTill. These Terms of Use ("Terms") govern your '
              'access to and use of the PocketTill application, website, '
              'software, services and related products ("PocketTill", '
              '"Service", "we", "us" or "our").',
          'By creating an account or using PocketTill, you agree to these '
              'Terms. If you do not agree with these Terms, you should not '
              'use the Service.',
        ],
        sections: [
          LegalSection('1. About PocketTill', [
            LegalParagraph(
              'PocketTill is a point-of-sale and shop-management platform '
              'designed primarily for informal retailers, including '
              'spaza shops and small retail businesses.',
            ),
            LegalParagraph('PocketTill may provide features including:'),
            LegalBullets([
              'Recording and managing sales',
              'Managing products and stock',
              'Recording and managing customer credit',
              'Viewing sales history',
              'Viewing business analytics and reports',
              'Searching for products',
              'Requesting products to be added to the PocketTill product '
                  'database',
              'Other features that we may introduce from time to time',
            ]),
            LegalParagraph(
              'We may modify, improve, add or remove features from the '
              'Service as PocketTill develops.',
            ),
          ]),
          LegalSection('2. Eligibility and Account Registration', [
            LegalParagraph(
              'To use PocketTill, you must provide information that is '
              'reasonably required to create and maintain your account.',
            ),
            LegalParagraph(
              'You agree that the information you provide should be '
              'accurate and kept reasonably up to date.',
            ),
            LegalParagraph(
              'You are responsible for maintaining the confidentiality of '
              'your account credentials, taking reasonable steps to '
              'prevent unauthorised access, ensuring information entered '
              'into PocketTill is accurate, and not allowing another '
              'person to use your account in a manner that compromises '
              'its security.',
            ),
            LegalParagraph(
              'You must notify PocketTill if you believe that your '
              'account has been accessed without your permission.',
            ),
          ]),
          LegalSection('3. Your Shop Data', [
            LegalParagraph(
              'PocketTill allows you to enter and store information '
              'relating to your shop.',
            ),
            LegalParagraph('This may include:'),
            LegalBullets([
              'Shop name',
              'Sales records and sales history',
              'Product and stock information',
              'Business analytics',
              'Credit-customer information',
              'Other information that you choose to enter into the '
                  'Service',
            ]),
            LegalParagraph(
              'You retain your rights in the business information that '
              'you provide to PocketTill. You grant PocketTill the '
              'limited rights necessary to store, process, display and '
              'otherwise use this information to provide, maintain, '
              'secure and improve the Service.',
            ),
          ]),
          LegalSection('4. Credit-Customer Information', [
            LegalParagraph(
              'PocketTill may allow you to record information about '
              'customers who purchase goods on credit.',
            ),
            LegalParagraph(
              'You are responsible for ensuring that you have a lawful '
              'basis for collecting and entering personal information '
              'about your customers into PocketTill.',
            ),
            LegalParagraph(
              'You should only enter information that is reasonably '
              "necessary for managing your shop's credit activities.",
            ),
            LegalParagraph(
              'PocketTill does not take ownership of the relationship '
              'between you and your credit customers. PocketTill provides '
              'software to help you manage that information.',
            ),
          ]),
          LegalSection('5. Account Recovery and Verification', [
            LegalParagraph(
              'If you lose access to your PocketTill account or request '
              'assistance recovering your account, PocketTill may use '
              'information already associated with your shop to help '
              'verify that you are the legitimate account holder.',
            ),
            LegalParagraph(
              'Depending on the circumstances, verification may include '
              'asking you questions about information associated with '
              'your shop, which may include your shop name, approximate '
              'or average sales activity, and information relating to '
              'your recorded credit customers.',
            ),
            LegalParagraph(
              'The purpose of this process is to help protect accounts '
              'against unauthorised access. PocketTill does not guarantee '
              'that account recovery will always be possible.',
            ),
          ]),
          LegalSection('6. Crowdsourced Product Catalogue', [
            LegalParagraph(
              'PocketTill may allow users to contribute product '
              'information to a shared product catalogue.',
            ),
            LegalParagraph(
              'By submitting product information to the shared catalogue, '
              'you grant PocketTill permission to store, use, modify, '
              'standardise, organise and make that product information '
              'available to other PocketTill users as part of the '
              'Service.',
            ),
            LegalParagraph(
              'You should only submit product information that you have '
              'the right to provide.',
            ),
            LegalParagraph(
              'The shared catalogue is intended to contain general '
              "product information and does not include a user's private "
              'shop records merely because that user contributed a '
              'product.',
            ),
            LegalParagraph(
              'PocketTill may modify, merge, remove or correct catalogue '
              'entries where reasonably necessary to maintain the '
              'accuracy and quality of the catalogue.',
            ),
            LegalParagraph(
              'PocketTill may also use aggregated information from the '
              'product catalogue to improve its product database, '
              'analytics and services.',
            ),
          ]),
          LegalSection('7. Acceptable Use', [
            LegalParagraph('You agree not to:'),
            LegalBullets([
              'Use PocketTill for unlawful purposes',
              "Attempt to gain unauthorised access to another user's "
                  'account',
              'Attempt to interfere with or disrupt the Service',
              'Reverse engineer, decompile or otherwise attempt to '
                  'extract the underlying source code of PocketTill, '
                  'except where permitted by applicable law',
              'Upload malicious software or other harmful material',
              "Use PocketTill to violate another person's privacy or "
                  'legal rights',
              'Enter information that you do not have the right or '
                  'lawful basis to process',
              'Use the Service in a way that could damage PocketTill, '
                  'its users or its systems',
            ]),
          ]),
          LegalSection('8. Accuracy of Information', [
            LegalParagraph(
              'PocketTill provides tools for recording and analysing '
              'business information. You are responsible for reviewing '
              'the information you enter and ensuring that your business '
              'records are accurate.',
            ),
            LegalParagraph(
              'PocketTill does not guarantee that analytics, reports or '
              'other calculations will always be free from errors, '
              'particularly where information entered by the user is '
              'incomplete or incorrect.',
            ),
            LegalParagraph(
              'PocketTill should not be treated as a substitute for '
              'professional accounting, tax, legal or financial advice.',
            ),
          ]),
          LegalSection('9. Availability of the Service', [
            LegalParagraph(
              'We aim to keep PocketTill available and reliable, but we '
              'do not guarantee that the Service will always be available '
              'without interruption.',
            ),
            LegalParagraph(
              'The Service may occasionally be unavailable because of '
              'maintenance, software updates, technical problems, '
              'internet or network failures, third-party service '
              'interruptions, security incidents, or circumstances '
              'outside our reasonable control.',
            ),
            LegalParagraph(
              'We may temporarily restrict access where reasonably '
              'necessary to protect PocketTill, its users or our '
              'systems.',
            ),
          ]),
          LegalSection('10. Third-Party Services', [
            LegalParagraph(
              'PocketTill may rely on third-party providers to operate '
              'certain parts of the Service, including infrastructure, '
              'authentication, communications, hosting, analytics or '
              'other technical services.',
            ),
            LegalParagraph(
              "These providers may process information on PocketTill's "
              'behalf where necessary to provide their services.',
            ),
            LegalParagraph(
              'PocketTill will take reasonable steps to use appropriate '
              'providers and protect information processed through such '
              'services.',
            ),
          ]),
          LegalSection('11. Data and Privacy', [
            LegalParagraph(
              'Your use of PocketTill is also governed by our Privacy '
              'Policy. The Privacy Policy explains what information we '
              'collect, why we collect it, how we use it, how we protect '
              'it and the rights available to data subjects.',
            ),
          ]),
          LegalSection('12. Aggregated and Anonymised Information', [
            LegalParagraph(
              'PocketTill may analyse information generated through the '
              'Service to understand general trends and improve its '
              'products and services.',
            ),
            LegalParagraph(
              'Where legally permitted, PocketTill may create aggregated '
              'or anonymised information relating to retail trends, '
              'product categories, sales patterns, shop activity, stock '
              'trends, general business performance and other statistical '
              'information.',
            ),
            LegalParagraph(
              'PocketTill will not intentionally use aggregated or '
              'anonymised information to identify a particular shop or '
              'individual.',
            ),
            LegalParagraph(
              'If PocketTill proposes to use personal information for a '
              'new purpose that is not compatible with the purpose for '
              'which the information was originally collected, PocketTill '
              'will take any steps required by applicable law before '
              'doing so.',
            ),
          ]),
          LegalSection('13. Intellectual Property', [
            LegalParagraph(
              'PocketTill and its software, branding, designs, logos, '
              'interfaces, content and technology are owned by or '
              'licensed to PocketTill and are protected by applicable '
              'intellectual property laws.',
            ),
            LegalParagraph(
              "These Terms do not transfer ownership of PocketTill's "
              'intellectual property to you.',
            ),
          ]),
          LegalSection('14. Feedback', [
            LegalParagraph(
              'If you provide suggestions, ideas or feedback regarding '
              'PocketTill, you agree that PocketTill may use that '
              'feedback to improve the Service without owing you '
              'compensation, provided that doing so does not disclose '
              'your confidential personal or business information.',
            ),
          ]),
          LegalSection('15. Suspension and Termination', [
            LegalParagraph('You may stop using PocketTill at any time.'),
            LegalParagraph(
              'PocketTill may suspend or terminate an account where '
              'reasonably necessary, including where the user materially '
              'breaches these Terms, the account is used unlawfully, the '
              'account creates a security risk, the user attempts to '
              'abuse or compromise the Service, or continued access would '
              'expose PocketTill or another user to significant risk.',
            ),
            LegalParagraph(
              'Where reasonably possible, PocketTill will provide notice '
              'before terminating an account unless immediate action is '
              'required for security, legal or operational reasons.',
            ),
          ]),
          LegalSection('16. Data After Account Termination', [
            LegalParagraph(
              'When an account is closed, PocketTill may retain certain '
              'information for as long as reasonably necessary to comply '
              'with legal obligations, resolve disputes, prevent fraud or '
              'abuse, maintain security, or fulfil other legitimate '
              'purposes permitted by applicable law.',
            ),
            LegalParagraph(
              'Information that is no longer required will be deleted, '
              'destroyed or anonymised in accordance with our retention '
              'practices and applicable law.',
            ),
          ]),
          LegalSection('17. Disclaimers', [
            LegalParagraph(
              'PocketTill is provided as a software service to assist '
              'with shop management.',
            ),
            LegalParagraph(
              'To the extent permitted by applicable law, PocketTill does '
              'not guarantee that the Service will always be '
              'uninterrupted, completely error-free, that business '
              'results will improve as a result of using PocketTill, or '
              'that information entered by users will be accurate.',
            ),
            LegalParagraph(
              'Nothing in these Terms excludes or limits any right or '
              'protection that cannot lawfully be excluded or limited '
              'under South African law.',
            ),
          ]),
          LegalSection('18. Limitation of Liability', [
            LegalParagraph(
              'To the maximum extent permitted by law, PocketTill will '
              'not be responsible for indirect, incidental, special or '
              'consequential losses arising from the use of the Service, '
              'including loss of profits, business interruption or loss '
              'of anticipated business opportunities.',
            ),
            LegalParagraph(
              'Nothing in these Terms limits liability where such '
              'limitation is prohibited by applicable law.',
            ),
          ]),
          LegalSection('19. Changes to These Terms', [
            LegalParagraph(
              'We may update these Terms from time to time. When we make '
              'material changes, we will take reasonable steps to notify '
              'users, such as displaying a notice within the Service or '
              'updating the date shown at the beginning of these Terms.',
            ),
            LegalParagraph(
              'Your continued use of PocketTill after updated Terms '
              'become effective constitutes acceptance of the updated '
              'Terms, to the extent permitted by law.',
            ),
          ]),
          LegalSection('20. Governing Law', [
            LegalParagraph(
              'These Terms are governed by the laws of the Republic of '
              'South Africa. Any dispute relating to these Terms will be '
              'subject to the applicable courts and dispute-resolution '
              'mechanisms of South Africa.',
            ),
          ]),
          LegalSection('21. Contact', [
            LegalParagraph('PocketTill (Pty) Ltd'),
            LegalParagraph('Website: https://pockettill.co.za'),
            LegalParagraph('Email: hello@pockettill.co.za'),
          ]),
        ],
      ),
    );
  }
}
