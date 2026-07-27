import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/return_record.dart';
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

/// The currently selected filter period. Defaults to Today.
final historyFilterProvider = StateProvider<HistoryFilter>(
  (ref) => HistoryFilter.today,
);

/// The date range chosen via the custom date-range picker, if any. Only
/// meaningful when [historyFilterProvider] is [HistoryFilter.custom].
final historyCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Resolves [filter] (plus [customRange] when it's [HistoryFilter.custom])
/// into a concrete `(from, to)` range - shared by the sales and returns
/// providers so both filter to exactly the same period.
(DateTime, DateTime) _resolveRange(
  HistoryFilter filter,
  DateTimeRange? customRange,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case HistoryFilter.today:
      return (now, now);
    case HistoryFilter.thisWeek:
      // A rolling 7-day window (today plus the 6 days before it) rather
      // than a Monday-start calendar week, so "yesterday" always shows up
      // here regardless of which day of the week it is.
      return (today.subtract(const Duration(days: 6)), today);
    case HistoryFilter.thisMonth:
      return (DateTime(now.year, now.month, 1), today);
    case HistoryFilter.custom:
      if (customRange == null) return (now, now);
      return (customRange.start, customRange.end);
  }
}

/// Sales matching the currently selected period, newest first.
final filteredSalesProvider = FutureProvider<List<Sale>>((ref) async {
  final filter = ref.watch(historyFilterProvider);
  final customRange = ref.watch(historyCustomRangeProvider);
  final repo = ref.watch(saleRepositoryProvider);
  final (from, to) = _resolveRange(filter, customRange);

  if (filter == HistoryFilter.today ||
      (filter == HistoryFilter.custom && customRange == null)) {
    return repo.getByDate(from);
  }
  return repo.getDateRange(from, to);
});

/// Returns processed within the currently selected period, newest first -
/// same period [filteredSalesProvider] uses, so a return always shows up
/// alongside sales from the same window.
final filteredReturnsProvider = FutureProvider<List<ReturnRecord>>((ref) async {
  final filter = ref.watch(historyFilterProvider);
  final customRange = ref.watch(historyCustomRangeProvider);
  final repo = ref.watch(returnRepositoryProvider);
  final (from, to) = _resolveRange(filter, customRange);

  if (filter == HistoryFilter.today ||
      (filter == HistoryFilter.custom && customRange == null)) {
    return repo.getByDate(from);
  }
  return repo.getDateRange(from, to);
});

/// A single row in the Sales History list - either a [Sale] or a
/// [ReturnRecord], sorted together by when each happened. Returns are their
/// own entries rather than being folded into the sale they came from, since
/// a return can happen well after (and separately from) its original sale.
sealed class HistoryEntry {
  DateTime get createdAt;
}

class SaleHistoryEntry extends HistoryEntry {
  SaleHistoryEntry(this.sale);

  final Sale sale;

  @override
  DateTime get createdAt => sale.createdAt;
}

class ReturnHistoryEntry extends HistoryEntry {
  ReturnHistoryEntry(this.returnRecord);

  final ReturnRecord returnRecord;

  @override
  DateTime get createdAt => returnRecord.createdAt;
}

/// Sales and returns for the current period, merged into one newest-first
/// list for the history screen to group and render.
final combinedHistoryProvider = Provider<List<HistoryEntry>>((ref) {
  final sales = ref.watch(filteredSalesProvider).valueOrNull ?? const [];
  final returns = ref.watch(filteredReturnsProvider).valueOrNull ?? const [];

  final entries = <HistoryEntry>[
    ...sales.map(SaleHistoryEntry.new),
    ...returns.map(ReturnHistoryEntry.new),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return entries;
});

/// Headline numbers derived from [filteredSalesProvider]'s current sales,
/// with [total] further adjusted by [filteredReturnsProvider]'s net money
/// movement - a return should reduce (or, for a customer-pays-more
/// exchange, increase) the revenue figure the owner sees. Count, average
/// sale, and cash percentage stay based on sales alone - those describe the
/// sales themselves, not the money that came back afterwards.
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
  final returns = ref.watch(filteredReturnsProvider).valueOrNull ?? const [];

  final salesTotal = sales.fold<double>(0, (sum, sale) => sum + sale.total);
  final returnsNet = returns.fold<double>(
    0,
    (sum, r) => sum + r.netMoneyMovement,
  );
  final total = salesTotal + returnsNet;

  final count = sales.length;
  final average = count == 0 ? 0.0 : salesTotal / count;

  final cashTotal = sales
      .where((sale) => sale.paymentType == 'cash')
      .fold<double>(0, (sum, sale) => sum + sale.total);
  final cashPercent = salesTotal == 0 ? 0.0 : (cashTotal / salesTotal) * 100;

  return HistorySummary(
    total: total,
    count: count,
    averageSale: average,
    cashPercent: cashPercent,
  );
});
