import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// How a [CreditCustomer.balance] should read on screen for a cashier: a
/// customer who owes money is more intuitive as a plain positive number in
/// red, while a balance in the customer's favour (the store owes them - from
/// store credit or an over-refund) is a negative number in green. The
/// underlying value is never changed - only how it's displayed.
String formatCreditBalance(double balance) {
  if (balance < 0) return '-R${(-balance).toStringAsFixed(2)}';
  return 'R${balance.toStringAsFixed(2)}';
}

/// Red when the customer owes money, green when the store owes the
/// customer, neutral grey when settled at zero.
Color creditBalanceColor(double balance) {
  if (balance > 0) return AppTheme.logoutRed;
  if (balance < 0) return AppTheme.syncGreen;
  return AppTheme.textSecondary;
}
