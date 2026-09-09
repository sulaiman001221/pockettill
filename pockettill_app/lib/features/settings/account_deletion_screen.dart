import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';

const String _deletionWhatsAppNumber = '27625631968';
const String _deletionEmail = 'hello@pockettill.co.za';

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

const List<String> _deletedItems = [
  'Your store and all its data',
  'All sales and transaction history',
  'All stock records',
  'All customer credit records',
  'All synced data on Supabase',
];

/// Mirrors the PocketTill landing website's own account/data deletion page
/// inside the app itself (Settings > Delete Account), so a store owner
/// doesn't have to leave the app to find out how. Manual deletion via
/// WhatsApp/email only for beta - no automated self-deletion yet, per
/// explicit instruction (2026-09-09).
class AccountDeletionScreen extends StatelessWidget {
  const AccountDeletionScreen({super.key});

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/$_deletionWhatsAppNumber?text='
      '${Uri.encodeComponent("Hi, I'd like to delete my PocketTill account.")}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _deletionEmail,
      query: 'subject=${Uri.encodeComponent('Delete My PocketTill Account')}',
    );
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showMenuIcon: false,
        title: 'Delete Your Account',
      ),
      backgroundColor: AppTheme.background,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.logoutRed.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.logoutRed),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Deleting your account is permanent and cannot be '
                    'undone. All your store data, sales history, stock, '
                    'and customer records will be permanently deleted.',
                    style: TextStyle(
                      color: AppTheme.logoutRed,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('WHAT GETS DELETED', style: _sectionLabelStyle),
          const SizedBox(height: 12),
          for (final item in _deletedItems) _BulletRow(text: item),
          const SizedBox(height: 24),
          const Text('HOW TO DELETE', style: _sectionLabelStyle),
          const SizedBox(height: 12),
          const Text(
            'To request account deletion, contact us via WhatsApp:',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _launchWhatsApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
              ),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Contact via WhatsApp'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Send us your registered phone number and we will delete your '
            'account within 48 hours.',
            style: AppTheme.bodySubtitle,
          ),
          const SizedBox(height: 24),
          const Text(
            'Alternative: You can also email us at',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: _launchEmail,
            child: const Text(
              _deletionEmail,
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.divider.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'After deletion, your phone number can be used to create a '
              'new PocketTill account.',
              style: AppTheme.bodySubtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 6,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
