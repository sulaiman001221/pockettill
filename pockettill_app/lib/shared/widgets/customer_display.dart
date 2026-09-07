import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/credit_balance_display.dart';

/// Uniform blue rounded-square initials avatar for a customer - matches the
/// "New Customer Profile" icon tile on AddCustomerScreen's info banner.
/// Shared by the Customers list and the checkout screen's customer picker
/// so both stay visually identical rather than drifting apart again.
class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final initials = words.isEmpty
        ? '?'
        : words.length == 1
        ? words.first[0].toUpperCase()
        : (words.first[0] + words.last[0]).toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(size * (12 / 44)),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * (15 / 44),
        ),
      ),
    );
  }
}

/// A customer's balance status - "Settled"/"Credit RXXX" get a shaded pill,
/// "Owes RXXX" stays plain colored text. Shared by the Customers list and
/// the checkout screen's customer picker so both stay visually identical.
class CustomerBalanceStatus extends StatelessWidget {
  const CustomerBalanceStatus({super.key, required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    final owing = balance > 0;

    final String label;
    final Color color;
    final bool shaded;
    if (owing) {
      label = 'Owes ${formatCreditBalance(balance)}';
      color = AppTheme.logoutRed;
      shaded = false;
    } else if (balance < 0) {
      label = 'Credit ${formatCreditBalance(balance)}';
      color = AppTheme.syncGreen;
      shaded = true;
    } else {
      label = 'Settled';
      color = AppTheme.syncGreen;
      shaded = true;
    }

    if (!shaded) {
      return Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
