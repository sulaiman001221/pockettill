import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Empty scaffold for the Sales tab - content lands in a later stage.
class SalesScreen extends StatelessWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.point_of_sale, size: 64, color: AppTheme.subtleText),
            SizedBox(height: 16),
            Text('Sales', style: TextStyle(color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}
