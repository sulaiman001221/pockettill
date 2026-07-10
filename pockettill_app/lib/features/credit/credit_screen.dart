import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Empty scaffold for the Credit tab - content lands in a later stage.
class CreditScreen extends StatelessWidget {
  const CreditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Credit')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people, size: 64, color: AppTheme.subtleText),
            SizedBox(height: 16),
            Text('Credit', style: TextStyle(color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}
