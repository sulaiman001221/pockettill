import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../../shared/widgets/policy_section.dart';

/// Plain-language privacy policy, linked from Settings.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Privacy Policy'),
      backgroundColor: AppTheme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Your privacy, in plain language',
            style: AppTheme.mainTitle,
          ),
          const SizedBox(height: 8),
          const Text(
            "This explains what PocketTill collects, how it's used, and "
            'how it stays safe.',
            style: AppTheme.bodySubtitle,
          ),
          const SizedBox(height: 20),
          const PolicySection(
            title: 'What We Collect',
            points: [
              'Store name and owner details',
              'Sales and transaction records',
              'Stock information',
              'Customer credit records',
              'Device information (to keep your account secure)',
            ],
          ),
          const PolicySection(
            title: 'How We Use It',
            points: [
              'To provide the POS service you signed up for',
              'To sync your data across sessions and devices',
              'It is never sold to third parties',
            ],
          ),
          const PolicySection(
            title: 'How It Is Stored',
            points: [
              'Locally on your device using Isar - the app works fully '
                  'offline',
              'Backed up to Supabase automatically once you have an '
                  'internet connection',
              'Protected by row level security, so only your store can '
                  'ever read your data',
            ],
          ),
          const PolicySection(
            title: 'Contact Us',
            points: ['WhatsApp +27625631968 for any privacy questions'],
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
