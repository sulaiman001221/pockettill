import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../../shared/widgets/policy_section.dart';

/// Plain-language terms of service, linked from Settings.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showMenuIcon: false,
        title: 'Terms of Service',
      ),
      backgroundColor: AppTheme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text('The basics', style: AppTheme.mainTitle),
          const SizedBox(height: 8),
          const Text(
            'PocketTill is currently in beta. Here is what that means for '
            'your store.',
            style: AppTheme.bodySubtitle,
          ),
          const SizedBox(height: 20),
          const PolicySection(
            title: 'Beta Period',
            points: [
              'PocketTill is free to use during the beta period',
              'Founding stores (the first 100 to qualify) receive a 50% '
                  'lifetime discount once billing begins',
              'The service may change - features can be added, adjusted, '
                  'or removed as the beta progresses',
            ],
          ),
          const PolicySection(
            title: 'Acceptable Use',
            points: [
              'Use PocketTill only for legitimate business record-keeping '
                  'and sales',
              "Do not attempt to access another store's data or interfere "
                  "with the service's normal operation",
            ],
          ),
          const PolicySection(
            title: 'Our Responsibility',
            points: [
              'We take reasonable care to keep your data safe and synced, '
                  'but we are not liable for data loss beyond that '
                  'reasonable care',
              'Keeping your device charged and occasionally connected to '
                  'the internet helps make sure your data backs up '
                  'reliably',
            ],
          ),
          const PolicySection(
            title: 'Contact for Disputes',
            points: ['WhatsApp +27625631968'],
          ),
          const SizedBox(height: 8),
          const Text(
            'Last updated: July 2026',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
