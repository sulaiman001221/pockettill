import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/sale.dart';
import '../../shared/repositories/repositories.dart';

/// The period a Sales History view is currently filtered to.
enum HistoryFilter { today, thisWeek, thisMonth, custom }

/// Display label for a [HistoryFilter].
String historyFilterLabel(HistoryFilter filter) {
  switch (filter) {
    case HistoryFilter.today:
      return 'Today';
    case HistoryFilter.thisWeek:
      return 'This Week';
    case HistoryFilter.thisMonth:
      return 'This Month';
    case HistoryFilter.custom:
      return 'Custom';
  }
}

/// The currently selected filter period. Defaults to This Week.
final historyFilterProvider = StateProvider<HistoryFilter>(
  (ref) => HistoryFilter.thisWeek,
);

/// The date range chosen via the custom date-range picker, if any. Only
/// meaningful when [historyFilterProvider] is [HistoryFilter.custom].
final historyCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Sales matching the currently selected period, newest first.
final filteredSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final filter = ref.watch(historyFilterProvider);
  final customRange = ref.watch(historyCustomRangeProvider);
  final repo = ref.watch(saleRepositoryProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case HistoryFilter.today:
      return repo.getByDate(now);
    case HistoryFilter.thisWeek:
      // A rolling 7-day window (today plus the 6 days before it) rather
      // than a Monday-start calendar week, so "yesterday" always shows up
      // here regardless of which day of the week it is.
      return repo.getDateRange(today.subtract(const Duration(days: 6)), today);
    case HistoryFilter.thisMonth:
      return repo.getDateRange(DateTime(now.year, now.month, 1), today);
    case HistoryFilter.custom:
      if (customRange == null) return repo.getByDate(now);
      return repo.getDateRange(customRange.start, customRange.end);
  }
});

/// Headline numbers derived from [filteredSalesProvider]'s current sales.
class HistorySummary {
  const HistorySummary({
    required this.total,
    required this.count,
    required this.averageSale,
    required this.cashPercent,
  });

  final double total;
  final int count;
  final double averageSale;
  final double cashPercent;
}

final historySummaryProvider = Provider<HistorySummary>((ref) {
  final sales = ref.watch(filteredSalesProvider).valueOrNull ?? const [];

  final total = sales.fold<double>(0, (sum, sale) => sum + sale.total);
  final count = sales.length;
  final average = count == 0 ? 0.0 : total / count;

  final cashTotal = sales
      .where((sale) => sale.paymentType == 'cash')
      .fold<double>(0, (sum, sale) => sum + sale.total);
  final cashPercent = total == 0 ? 0.0 : (cashTotal / total) * 100;

  return HistorySummary(
    total: total,
    count: count,
    averageSale: average,
    cashPercent: cashPercent,
  );
});
