import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';

/// Empty scaffold for Customers (credit/tab customers) - content lands in a
/// later stage.
class CreditScreen extends StatelessWidget {
  const CreditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Customers'),
      backgroundColor: AppTheme.background,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outlined, size: 64, color: AppTheme.iconBorder),
            SizedBox(height: 16),
            Text('Customers', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
