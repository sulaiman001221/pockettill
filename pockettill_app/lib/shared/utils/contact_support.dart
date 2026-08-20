import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const String supportWhatsAppNumber = '27625631968';
const String supportEmail = 'support@pockettill.co.za';

/// Shows a small sheet letting the user pick WhatsApp or email to reach
/// support - the single place every "Contact Support" action in the app
/// goes through, so both channels always stay in sync everywhere one is
/// offered rather than each screen hardcoding just WhatsApp.
Future<void> showContactSupportOptions(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Contact Support', style: AppTheme.mainTitle),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined, color: AppTheme.primary),
            title: const Text('WhatsApp'),
            subtitle: const Text('+$supportWhatsAppNumber'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _launchWhatsApp();
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.email_outlined,
              color: AppTheme.primary,
            ),
            title: const Text('Email'),
            subtitle: const Text(supportEmail),
            onTap: () {
              Navigator.of(sheetContext).pop();
              _launchEmail();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _launchWhatsApp() async {
  final uri = Uri.parse('https://wa.me/$supportWhatsAppNumber');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _launchEmail() async {
  final uri = Uri(scheme: 'mailto', path: supportEmail);
  await launchUrl(uri);
}
