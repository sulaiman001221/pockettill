import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Empty scaffold for the Analytics tab - content lands in a later stage.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: AppTheme.subtleText),
            SizedBox(height: 16),
            Text('Analytics', style: TextStyle(color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}
