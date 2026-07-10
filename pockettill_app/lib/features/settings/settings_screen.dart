import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Empty scaffold for Settings - content lands in a later stage. Not a
/// bottom-nav tab; reached via the settings icon in the shell's AppBar.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, size: 64, color: AppTheme.subtleText),
            SizedBox(height: 16),
            Text('Settings', style: TextStyle(color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}
