import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/sale.dart';
import '../../shared/repositories/sale_repository.dart';

enum AnalyticsPeriod { daily, monthly, yearly }

/// A bar chart's per-category revenue totals, ready to hand to fl_chart,
/// plus the matching x-axis labels for the selected [AnalyticsPeriod].
class ChartSeries {
  const ChartSeries({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;
}

class AnalyticsState {
  const AnalyticsState({
    this.period = AnalyticsPeriod.daily,
    this.chartLoading = true,
    this.chartError,
    this.series,
    this.busiestLabel,
    this.currentTotal = 0,
    this.previousTotal = 0,
    this.currentCount = 0,
    this.previousCount = 0,
    this.cashAmount = 0,
    this.cardAmount = 0,
    this.creditAmount = 0,
    this.performanceLoading = true,
    this.performanceError,
    this.bestDayLabel,
    this.bestDayAmount = 0,
    this.avgSaleValue = 0,
    this.totalTransactions = 0,
    this.basketChangePercent,
  });

  final AnalyticsPeriod period;

  final bool chartLoading;
  final String? chartError;
  final ChartSeries? series;
  final String? busiestLabel;

  // Selected-period headline stats (and their previous-period counterparts
  // for the "vs. prev" deltas), all loaded together with the chart.
  final double currentTotal;
  final double previousTotal;
  final int currentCount;
  final int previousCount;

  // Selected-period revenue split by payment method.
  final double cashAmount;
  final double cardAmount;
  final double creditAmount;

  final bool performanceLoading;
  final String? performanceError;
  final String? bestDayLabel;
  final double bestDayAmount;
  final double avgSaleValue;
  final int totalTransactions;

  /// Null hides the basket-comparison row - either still loading, or last
  /// week had no sales to compare against.
  final double? basketChangePercent;

  double get currentAvgSale =>
      currentCount == 0 ? 0 : currentTotal / currentCount;
  double get previousAvgSale =>
      previousCount == 0 ? 0 : previousTotal / previousCount;

  AnalyticsState copyWith({
    AnalyticsPeriod? period,
    bool? chartLoading,
    Object? chartError = _unset,
    Object? series = _unset,
    Object? busiestLabel = _unset,
    double? currentTotal,
    double? previousTotal,
    int? currentCount,
    int? previousCount,
    double? cashAmount,
    double? cardAmount,
    double? creditAmount,
    bool? performanceLoading,
    Object? performanceError = _unset,
    Object? bestDayLabel = _unset,
    double? bestDayAmount,
    double? avgSaleValue,
    int? totalTransactions,
    Object? basketChangePercent = _unset,
  }) {
    return AnalyticsState(
      period: period ?? this.period,
      chartLoading: chartLoading ?? this.chartLoading,
      chartError: chartError == _unset ? this.chartError : chartError as String?,
      series: series == _unset ? this.series : series as ChartSeries?,
      busiestLabel: busiestLabel == _unset
          ? this.busiestLabel
          : busiestLabel as String?,
      currentTotal: currentTotal ?? this.currentTotal,
      previousTotal: previousTotal ?? this.previousTotal,
      currentCount: currentCount ?? this.currentCount,
      previousCount: previousCount ?? this.previousCount,
      cashAmount: cashAmount ?? this.cashAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      creditAmount: creditAmount ?? this.creditAmount,
      performanceLoading: performanceLoading ?? this.performanceLoading,
      performanceError: performanceError == _unset
          ? this.performanceError
          : performanceError as String?,
      bestDayLabel: bestDayLabel == _unset ? this.bestDayLabel : bestDayLabel as String?,
      bestDayAmount: bestDayAmount ?? this.bestDayAmount,
      avgSaleValue: avgSaleValue ?? this.avgSaleValue,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      basketChangePercent: basketChangePercent == _unset
          ? this.basketChangePercent
          : basketChangePercent as double?,
    );
  }
}

/// Sentinel distinguishing "not passed" from "explicitly passed null" in
/// [AnalyticsState.copyWith], since several fields are legitimately nullable.
const Object _unset = Object();

/// Owns every number on the Analytics screen. The chart section (which also
/// feeds the headline stats and payment breakdown) and the performance
/// section load and fail independently, so one slow or broken repository
/// call never blanks out the whole screen.
class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  AnalyticsNotifier({required SaleRepository saleRepository})
    : _saleRepository = saleRepository,
      super(const AnalyticsState()) {
    loadAll();
  }

  final SaleRepository _saleRepository;

  /// Loads every section in parallel. Called once on startup and by
  /// pull-to-refresh.
  Future<void> loadAll() async {
    await Future.wait([_loadChartData(state.period), _loadPerformance()]);
  }

  Future<void> setPeriod(AnalyticsPeriod period) async {
    if (period == state.period && state.series != null) return;
    await _loadChartData(period);
  }

  Future<void> retryChart() => _loadChartData(state.period);
  Future<void> retryPerformance() => _loadPerformance();

  Future<void> _loadChartData(AnalyticsPeriod period) async {
    state = state.copyWith(period: period, chartLoading: true, chartError: null);

    try {
      final now = DateTime.now();
      List<Sale> current;
      List<Sale> previous;

      switch (period) {
        case AnalyticsPeriod.daily:
          // "Daily" is a Sun-Sat calendar-week bar chart, not today's hours -
          // a single day of hourly bars read as noise to shop owners.
          final sunday = DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: now.weekday % 7));
          final saturday = sunday.add(const Duration(days: 6));
          current = await _saleRepository.getDateRange(sunday, saturday);
          final prevSunday = sunday.subtract(const Duration(days: 7));
          final prevSaturday = prevSunday.add(const Duration(days: 6));
          previous = await _saleRepository.getDateRange(prevSunday, prevSaturday);
        case AnalyticsPeriod.monthly:
          // "Monthly" is the current year broken down Jan-Dec, compared
          // against last year's full total.
          final firstOfYear = DateTime(now.year, 1, 1);
          current = await _saleRepository.getDateRange(firstOfYear, now);
          previous = await _saleRepository.getDateRange(
            DateTime(now.year - 1, 1, 1),
            DateTime(now.year - 1, 12, 31),
          );
        case AnalyticsPeriod.yearly:
          // "Yearly" is the past 5 calendar years, one bar per year.
          final startYear = now.year - 4;
          current = await _saleRepository.getDateRange(
            DateTime(startYear, 1, 1),
            now,
          );
          previous = await _saleRepository.getDateRange(
            DateTime(startYear - 5, 1, 1),
            DateTime(startYear - 1, 12, 31),
          );
      }

      var cashAmount = 0.0;
      var cardAmount = 0.0;
      var creditAmount = 0.0;
      var currentTotal = 0.0;
      for (final sale in current) {
        currentTotal += sale.total;
        switch (sale.paymentType) {
          case 'cash':
            cashAmount += sale.total;
          case 'card':
            cardAmount += sale.total;
          case 'credit':
            creditAmount += sale.total;
        }
      }
      final previousTotal = previous.fold<double>(0, (sum, s) => sum + s.total);

      final input = _ChartComputeInput(
        period: period,
        current: [
          for (final s in current) _SalePoint(s.createdAt.millisecondsSinceEpoch, s.total),
        ],
        referenceMillis: now.millisecondsSinceEpoch,
      );
      final result = await compute(_computeChartData, input);

      final series = ChartSeries(values: result.values, labels: result.labels);

      state = state.copyWith(
        series: series,
        busiestLabel: result.busiestLabel,
        currentTotal: currentTotal,
        previousTotal: previousTotal,
        currentCount: current.length,
        previousCount: previous.length,
        cashAmount: cashAmount,
        cardAmount: cardAmount,
        creditAmount: creditAmount,
        chartLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        chartLoading: false,
        chartError: 'Could not load chart data. Please try again.',
      );
    }
  }

  Future<void> _loadPerformance() async {
    state = state.copyWith(performanceLoading: true, performanceError: null);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final weeklySales = await _saleRepository.getWeeklySales();
      final previousWeekSales = await _saleRepository.getDateRange(
        today.subtract(const Duration(days: 13)),
        today.subtract(const Duration(days: 7)),
      );

      String? bestDayLabel;
      var bestDayAmount = 0.0;
      for (final day in weeklySales) {
        final total = day['total'] as double;
        if (total > bestDayAmount) {
          bestDayAmount = total;
          bestDayLabel = DateFormat('EEEE').format(day['date'] as DateTime);
        }
      }

      final totalRevenue = weeklySales.fold<double>(
        0,
        (sum, d) => sum + (d['total'] as double),
      );
      final totalTrans = weeklySales.fold<int>(
        0,
        (sum, d) => sum + (d['transactionCount'] as int),
      );
      final avgSaleValue = totalTrans == 0 ? 0.0 : totalRevenue / totalTrans;

      final prevTotalRevenue = previousWeekSales.fold<double>(
        0,
        (sum, s) => sum + s.total,
      );
      final prevAvgSaleValue = previousWeekSales.isEmpty
          ? null
          : prevTotalRevenue / previousWeekSales.length;

      double? basketChangePercent;
      if (prevAvgSaleValue != null && prevAvgSaleValue > 0) {
        basketChangePercent =
            ((avgSaleValue - prevAvgSaleValue) / prevAvgSaleValue) * 100;
      }

      state = state.copyWith(
        bestDayLabel: bestDayLabel,
        bestDayAmount: bestDayAmount,
        avgSaleValue: avgSaleValue,
        totalTransactions: totalTrans,
        basketChangePercent: basketChangePercent,
        performanceLoading: false,
      );
    } catch (_) {
      state = state.copyWith(
        performanceLoading: false,
        performanceError: 'Could not load performance data. Please try again.',
      );
    }
  }
}

/// A single sale reduced to just what the isolate needs - plain data only,
/// so it's guaranteed safe to send across the [compute] boundary regardless
/// of how Isar's generated model classes are represented internally.
class _SalePoint {
  const _SalePoint(this.millis, this.total);
  final int millis;
  final double total;
}

class _ChartComputeInput {
  const _ChartComputeInput({
    required this.period,
    required this.current,
    required this.referenceMillis,
  });

  final AnalyticsPeriod period;
  final List<_SalePoint> current;
  final int referenceMillis;
}

class _ChartComputeResult {
  const _ChartComputeResult({
    required this.values,
    required this.labels,
    this.busiestLabel,
  });

  final List<double> values;
  final List<String> labels;
  final String? busiestLabel;
}

/// Runs on a background isolate via [compute] - buckets raw sale points into
/// the bar-chart series for the selected period.
_ChartComputeResult _computeChartData(_ChartComputeInput input) {
  switch (input.period) {
    case AnalyticsPeriod.daily:
      return _computeWeekly(input);
    case AnalyticsPeriod.monthly:
      return _computeMonthlyOfYear(input);
    case AnalyticsPeriod.yearly:
      return _computeYearly(input);
  }
}

const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _weekdayNames = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

/// Sun-Sat calendar week, one bar per day (index 0 = Sunday).
_ChartComputeResult _computeWeekly(_ChartComputeInput input) {
  final byWeekday = List<double>.filled(7, 0);
  final countByWeekday = List<int>.filled(7, 0);

  for (final p in input.current) {
    final index = DateTime.fromMillisecondsSinceEpoch(p.millis).weekday % 7;
    byWeekday[index] += p.total;
    countByWeekday[index] += 1;
  }

  var busiestIndex = -1;
  var busiestCount = 0;
  for (var i = 0; i < 7; i++) {
    if (countByWeekday[i] > busiestCount) {
      busiestCount = countByWeekday[i];
      busiestIndex = i;
    }
  }

  return _ChartComputeResult(
    values: byWeekday,
    labels: _weekdayLabels,
    busiestLabel: busiestIndex == -1 ? null : _weekdayNames[busiestIndex],
  );
}

const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Current calendar year, one bar per month (Jan-Dec).
_ChartComputeResult _computeMonthlyOfYear(_ChartComputeInput input) {
  final byMonth = List<double>.filled(12, 0);

  for (final p in input.current) {
    final month = DateTime.fromMillisecondsSinceEpoch(p.millis).month;
    byMonth[month - 1] += p.total;
  }

  return _ChartComputeResult(values: byMonth, labels: _monthLabels);
}

/// Past 5 calendar years (inclusive of this year), one bar per year.
_ChartComputeResult _computeYearly(_ChartComputeInput input) {
  final now = DateTime.fromMillisecondsSinceEpoch(input.referenceMillis);
  final startYear = now.year - 4;
  final byYear = List<double>.filled(5, 0);

  for (final p in input.current) {
    final year = DateTime.fromMillisecondsSinceEpoch(p.millis).year;
    final index = year - startYear;
    if (index >= 0 && index < 5) byYear[index] += p.total;
  }

  return _ChartComputeResult(
    values: byYear,
    labels: [for (var y = startYear; y <= now.year; y++) '$y'],
  );
}
