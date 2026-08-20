import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/risk_log.dart';
import '../../shared/repositories/repositories.dart';

/// The period a Risk Log view is currently filtered to - mirrors
/// HistoryFilter in features/history/history_providers.dart.
enum RiskLogFilter { today, thisWeek, thisMonth, custom }

/// Display label for a [RiskLogFilter].
String riskLogFilterLabel(RiskLogFilter filter) {
  switch (filter) {
    case RiskLogFilter.today:
      return 'Today';
    case RiskLogFilter.thisWeek:
      return 'This Week';
    case RiskLogFilter.thisMonth:
      return 'This Month';
    case RiskLogFilter.custom:
      return 'Custom';
  }
}

/// The currently selected filter period. Defaults to Today.
final riskLogFilterProvider = StateProvider<RiskLogFilter>(
  (ref) => RiskLogFilter.today,
);

/// The date range chosen via the custom date-range picker, if any. Only
/// meaningful when [riskLogFilterProvider] is [RiskLogFilter.custom].
final riskLogCustomRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

(DateTime, DateTime) _resolveRange(
  RiskLogFilter filter,
  DateTimeRange? customRange,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case RiskLogFilter.today:
      return (now, now);
    case RiskLogFilter.thisWeek:
      return (today.subtract(const Duration(days: 6)), today);
    case RiskLogFilter.thisMonth:
      return (DateTime(now.year, now.month, 1), today);
    case RiskLogFilter.custom:
      if (customRange == null) return (now, now);
      return (customRange.start, customRange.end);
  }
}

/// Risk Log entries matching the currently selected period, newest first.
final filteredRiskLogProvider = FutureProvider<List<RiskLog>>((ref) async {
  final filter = ref.watch(riskLogFilterProvider);
  final customRange = ref.watch(riskLogCustomRangeProvider);
  final repo = ref.watch(riskLogRepositoryProvider);
  final (from, to) = _resolveRange(filter, customRange);

  if (filter == RiskLogFilter.today ||
      (filter == RiskLogFilter.custom && customRange == null)) {
    return repo.getByDate(from);
  }
  return repo.getDateRange(from, to);
});
