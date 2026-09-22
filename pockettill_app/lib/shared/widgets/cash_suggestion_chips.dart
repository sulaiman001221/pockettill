import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quick-tap cash amount chips for a "cash received" field. "Exact" sets the
/// field to [amountDue] outright (change = 0); each note chip (R10/20/50/
/// 100/200) adds that note's value to whatever's already there, mirroring
/// how a cashier stacks physical notes handed over one at a time (e.g. two
/// R100 notes = tap "R100" twice).
class CashSuggestionChips extends StatelessWidget {
  const CashSuggestionChips({
    super.key,
    required this.amountDue,
    required this.currentAmount,
    required this.onAmountChanged,
  });

  final double amountDue;
  final double currentAmount;
  final ValueChanged<double> onAmountChanged;

  static const List<int> _notes = [10, 20, 50, 100, 200];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SuggestionChip(
            label: 'Exact',
            onTap: () => onAmountChanged(amountDue),
          ),
          for (final note in _notes) ...[
            const SizedBox(width: 8),
            _SuggestionChip(
              label: 'R$note',
              onTap: () => onAmountChanged(currentAmount + note),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
