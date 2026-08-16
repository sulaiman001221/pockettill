import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/credit_transaction.dart';
import '../../shared/models/extra_income.dart';
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

/// Extra income (non-sale) entries within the currently selected period -
/// same period [filteredSalesProvider] uses, so an entry always shows up
/// alongside sales from the same window.
final filteredExtraIncomeProvider = FutureProvider<List<ExtraIncome>>((
  ref,
) async {
  final filter = ref.watch(historyFilterProvider);
  final customRange = ref.watch(historyCustomRangeProvider);
  final repo = ref.watch(extraIncomeRepositoryProvider);
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

class ExtraIncomeHistoryEntry extends HistoryEntry {
  ExtraIncomeHistoryEntry(this.extraIncome);

  final ExtraIncome extraIncome;

  @override
  DateTime get createdAt => extraIncome.createdAt;
}

/// Sales, returns, and extra income for the current period, merged into one
/// newest-first list for the history screen to group and render.
final combinedHistoryProvider = Provider<List<HistoryEntry>>((ref) {
  final sales = ref.watch(filteredSalesProvider).valueOrNull ?? const [];
  final returns = ref.watch(filteredReturnsProvider).valueOrNull ?? const [];
  final extraIncome =
      ref.watch(filteredExtraIncomeProvider).valueOrNull ?? const [];

  final entries = <HistoryEntry>[
    ...sales.map(SaleHistoryEntry.new),
    ...returns.map(ReturnHistoryEntry.new),
    ...extraIncome.map(ExtraIncomeHistoryEntry.new),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return entries;
});

/// Simple headline numbers for the Sales History summary card - the
/// period's revenue (net of any returns, so it matches the transaction
/// list's own per-day totals), how many sales, the average sale value, and
/// what share of sales were paid in cash. The full cash/card/credit
/// reconciliation breakdown lives only in [EndOfDaySummary], not here.
class HistorySummary {
  const HistorySummary({
    required this.total,
    required this.count,
    required this.averageSale,
    required this.cashPercentage,
  });

  final double total;
  final int count;
  final double averageSale;

  /// Share of gross sales (0-100) paid in cash - returns don't factor in,
  /// since this describes how sales themselves were paid for.
  final double cashPercentage;
}

/// Headline numbers for the currently selected filter period.
final historySummaryProvider = Provider<HistorySummary>((ref) {
  final sales = ref.watch(filteredSalesProvider).valueOrNull ?? const [];
  final returns = ref.watch(filteredReturnsProvider).valueOrNull ?? const [];
  final extraIncome =
      ref.watch(filteredExtraIncomeProvider).valueOrNull ?? const [];

  final grossSales = sales.fold<double>(0, (sum, sale) => sum + sale.total);
  // Nets in returns so this matches the transaction list's own per-day
  // totals, which already fold each return's netMoneyMovement in alongside
  // its sales.
  final returnsNet = returns.fold<double>(
    0,
    (sum, r) => sum + r.netMoneyMovement,
  );
  final extraIncomeTotal = extraIncome.fold<double>(
    0,
    (sum, e) => sum + e.amount,
  );
  final total = grossSales + returnsNet + extraIncomeTotal;

  // Deliberately keyed off sales alone - extra income isn't a sale, so it
  // must not shift the sale count or the average sale value.
  final count = sales.length;
  final average = count == 0 ? 0.0 : grossSales / count;

  final cashSales = sales
      .where((s) => s.paymentType == 'cash')
      .fold<double>(0, (sum, s) => sum + s.total);
  final cashPercentage = grossSales == 0 ? 0.0 : (cashSales / grossSales) * 100;

  return HistorySummary(
    total: total,
    count: count,
    averageSale: average,
    cashPercentage: cashPercentage,
  );
});

/// Full till/card-machine reconciliation for a single calendar day - shown
/// on the End of Day Summary page for whichever day is requested,
/// independent of whatever period the Sales History filter chips currently
/// have selected.
///
/// A repayment's method (cash vs card) is read from
/// [CreditTransaction.note] ('Cash'/'Card', set by AddPaymentScreen) since
/// there's no dedicated field for it. [returnsNet] uses each return's own
/// [ReturnRecord.netMoneyMovement] - the same figure the Sales History
/// summary card nets into [totalRevenue] - rather than trying to split
/// refunds/exchanges by cash vs card vs credit-balance, so every number on
/// this page traces back to the exact same calculation.
class EndOfDaySummary {
  const EndOfDaySummary({
    required this.totalRevenue,
    required this.cashSales,
    required this.cardSales,
    required this.creditSales,
    required this.cashRepaymentsCollected,
    required this.cardRepaymentsCollected,
    required this.hasReturns,
    required this.returnsNet,
    required this.extraIncomeTotal,
    required this.totalExpected,
  });

  /// All sales regardless of payment type, net of today's returns and
  /// including extra income - the same figure [historySummaryProvider] shows
  /// on the Sales History summary card. Includes credit sales not yet
  /// received as cash.
  final double totalRevenue;

  final double cashSales;
  final double cardSales;

  /// Value of goods sold on credit today - not yet received.
  final double creditSales;

  /// Cash collected today from credit customers paying down their balance.
  final double cashRepaymentsCollected;

  /// Card-machine repayments collected today from credit customers.
  final double cardRepaymentsCollected;

  /// Whether any returns were processed today - [returnsNet] can
  /// legitimately land on exactly zero (a refund and an exchange overpayment
  /// cancelling out) even when returns did happen, so this is tracked
  /// separately rather than inferred from the net being non-zero.
  final bool hasReturns;

  /// Net effect of today's returns on money in hand - positive if returns
  /// brought money IN overall (an exchange where the customer paid extra),
  /// negative if they took money OUT (a refund, store credit, or a
  /// lower-value exchange), zero if there were none or they cancelled out.
  final double returnsNet;

  /// Today's one-off income that isn't a sale (airtime, electricity tokens,
  /// etc.) - real money received, so it's folded into [totalRevenue] and
  /// [totalExpected], but has no payment-type split of its own (the entry
  /// form has no field for one).
  final double extraIncomeTotal;

  /// Cash + card sales, plus all repayments collected, plus extra income,
  /// plus/minus today's returns - the actual money that came into the
  /// business today, excluding credit sales that were recorded but not yet
  /// paid.
  final double totalExpected;
}

/// Sales on the requested calendar day - independent of whatever period is
/// currently selected in the Sales History filter chips, since the End of
/// Day Summary page can be opened for any past day, not just today.
final _dailySalesProvider = FutureProvider.family<List<Sale>, DateTime>((
  ref,
  date,
) {
  return ref.watch(saleRepositoryProvider).getByDate(date);
});

final _dailyReturnsProvider = FutureProvider.family<List<ReturnRecord>, DateTime>((
  ref,
  date,
) {
  return ref.watch(returnRepositoryProvider).getByDate(date);
});

final _dailyCreditPaymentsProvider =
    FutureProvider.family<List<CreditTransaction>, DateTime>((ref, date) {
      return ref.watch(creditRepositoryProvider).getRepaymentsInRange(date, date);
    });

final _dailyExtraIncomeProvider =
    FutureProvider.family<List<ExtraIncome>, DateTime>((ref, date) {
      return ref.watch(extraIncomeRepositoryProvider).getByDate(date);
    });

/// Forces a fresh read of the End of Day summary for [date] - invalidating
/// only [endOfDaySummaryProvider] isn't enough, since it just recomputes
/// from whatever [_dailySalesProvider]/[_dailyReturnsProvider]/
/// [_dailyCreditPaymentsProvider]/[_dailyExtraIncomeProvider] last cached;
/// those are plain (non-autoDispose) families too, so each one keeps its own
/// stale result until invalidated in turn.
void refreshEndOfDaySummary(WidgetRef ref, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  ref.invalidate(_dailySalesProvider(day));
  ref.invalidate(_dailyReturnsProvider(day));
  ref.invalidate(_dailyCreditPaymentsProvider(day));
  ref.invalidate(_dailyExtraIncomeProvider(day));
  ref.invalidate(endOfDaySummaryProvider(day));
}

/// The End of Day reconciliation for [date] - async since classifying a
/// refund's cash/card bucket requires looking up its original sale. Callers
/// should pass a date normalised to midnight (year/month/day only) so the
/// family cache keys correctly regardless of time-of-day.
final endOfDaySummaryProvider =
    FutureProvider.family<EndOfDaySummary, DateTime>((ref, date) async {
  final sales = await ref.watch(_dailySalesProvider(date).future);
  final returns = await ref.watch(_dailyReturnsProvider(date).future);
  final repayments = await ref.watch(_dailyCreditPaymentsProvider(date).future);
  final extraIncome = await ref.watch(_dailyExtraIncomeProvider(date).future);

  final cashSales = sales
      .where((s) => s.paymentType == 'cash')
      .fold<double>(0, (sum, s) => sum + s.total);
  final cardSales = sales
      .where((s) => s.paymentType == 'card')
      .fold<double>(0, (sum, s) => sum + s.total);
  final creditSales = sales
      .where((s) => s.paymentType == 'credit')
      .fold<double>(0, (sum, s) => sum + s.total);
  final grossSales = cashSales + cardSales + creditSales;

  final cashRepayments = repayments
      .where((tx) => tx.note == 'Cash')
      .fold<double>(0, (sum, tx) => sum + tx.amount);
  final cardRepayments = repayments
      .where((tx) => tx.note == 'Card')
      .fold<double>(0, (sum, tx) => sum + tx.amount);

  final returnsNet = returns.fold<double>(
    0,
    (sum, r) => sum + r.netMoneyMovement,
  );
  final extraIncomeTotal = extraIncome.fold<double>(
    0,
    (sum, e) => sum + e.amount,
  );

  final totalRevenue = grossSales + returnsNet + extraIncomeTotal;
  final totalExpected =
      cashSales +
      cardSales +
      cashRepayments +
      cardRepayments +
      returnsNet +
      extraIncomeTotal;

  return EndOfDaySummary(
    totalRevenue: totalRevenue,
    cashSales: cashSales,
    cardSales: cardSales,
    creditSales: creditSales,
    cashRepaymentsCollected: cashRepayments,
    cardRepaymentsCollected: cardRepayments,
    hasReturns: returns.isNotEmpty,
    returnsNet: returnsNet,
    extraIncomeTotal: extraIncomeTotal,
    totalExpected: totalExpected,
  );
});
