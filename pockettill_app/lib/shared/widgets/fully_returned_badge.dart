import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown in place of a "Process Return" button once every item on a sale
/// has already been returned - used on both SaleDetailScreen and
/// TransactionDetailScreen, since the two share the same return-eligibility
/// rule.
class FullyReturnedBadge extends StatelessWidget {
  const FullyReturnedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.syncGrey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, color: AppTheme.syncGrey, size: 18),
          SizedBox(width: 8),
          Text(
            'Fully Returned',
            style: TextStyle(
              color: AppTheme.syncGrey,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
