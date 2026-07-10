import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Empty scaffold for the History tab - content lands in a later stage.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 64, color: AppTheme.subtleText),
            SizedBox(height: 16),
            Text('History', style: TextStyle(color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}
