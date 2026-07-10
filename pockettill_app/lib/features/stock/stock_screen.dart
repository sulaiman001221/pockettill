import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Empty scaffold for the Stock tab - content lands in a later stage.
class StockScreen extends StatelessWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2, size: 64, color: AppTheme.subtleText),
            SizedBox(height: 16),
            Text('Stock', style: TextStyle(color: AppTheme.subtleText)),
          ],
        ),
      ),
    );
  }
}
