import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/sale.dart';
import '../../shared/repositories/sale_repository.dart';

enum AnalyticsPeriod { daily, monthly, yearly }

/// A chart's current-period and previous-period series, ready to hand to
/// fl_chart, plus the x-axis labels for the selected [AnalyticsPeriod].
class ChartSeries {
  const ChartSeries({
    required this.currentSpots,
    required this.previousSpots,
    required this.labels,
  });

  final List<FlSpot> currentSpots;
  final List<FlSpot> previousSpots;
  final List<String> labels;
}

class AnalyticsState {
  const AnalyticsState({
    this.period = AnalyticsPeriod.daily,
    this.chartLoading = true,
    this.chartError,
    this.series,
    this.busiestHourLabel,
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
  final String? busiestHourLabel;

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
    Object? busiestHourLabel = _unset,
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
      busiestHourLabel: busiestHourLabel == _unset
          ? this.busiestHourLabel
          : busiestHourLabel as String?,
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
          current = await _saleRepository.getByDate(now);
          previous = await _saleRepository.getByDate(
            now.subtract(const Duration(days: 1)),
          );
        case AnalyticsPeriod.monthly:
          final firstOfMonth = DateTime(now.year, now.month, 1);
          current = await _saleRepository.getDateRange(firstOfMonth, now);
          final lastOfPrevMonth = firstOfMonth.subtract(const Duration(days: 1));
          final firstOfPrevMonth = DateTime(
            lastOfPrevMonth.year,
            lastOfPrevMonth.month,
            1,
          );
          previous = await _saleRepository.getDateRange(
            firstOfPrevMonth,
            lastOfPrevMonth,
          );
        case AnalyticsPeriod.yearly:
          final firstOfYear = DateTime(now.year, 1, 1);
          current = await _saleRepository.getDateRange(firstOfYear, now);
          previous = await _saleRepository.getDateRange(
            DateTime(now.year - 1, 1, 1),
            DateTime(now.year - 1, 12, 31),
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
        previous: [
          for (final s in previous) _SalePoint(s.createdAt.millisecondsSinceEpoch, s.total),
        ],
        referenceMillis: now.millisecondsSinceEpoch,
      );
      final result = await compute(_computeChartData, input);

      final series = ChartSeries(
        currentSpots: [
          for (var i = 0; i < result.currentValues.length; i++)
            FlSpot(i.toDouble(), result.currentValues[i]),
        ],
        previousSpots: [
          for (var i = 0; i < result.previousValues.length; i++)
            FlSpot(i.toDouble(), result.previousValues[i]),
        ],
        labels: result.labels,
      );

      state = state.copyWith(
        series: series,
        busiestHourLabel: result.busiestHourLabel,
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
    required this.previous,
    required this.referenceMillis,
  });

  final AnalyticsPeriod period;
  final List<_SalePoint> current;
  final List<_SalePoint> previous;
  final int referenceMillis;
}

class _ChartComputeResult {
  const _ChartComputeResult({
    required this.currentValues,
    required this.previousValues,
    required this.labels,
    this.busiestHourLabel,
  });

  final List<double> currentValues;
  final List<double> previousValues;
  final List<String> labels;
  final String? busiestHourLabel;
}

/// Runs on a background isolate via [compute] - buckets raw sale points into
/// the current/previous series for the selected period.
_ChartComputeResult _computeChartData(_ChartComputeInput input) {
  switch (input.period) {
    case AnalyticsPeriod.daily:
      return _computeDaily(input);
    case AnalyticsPeriod.monthly:
      return _computeMonthly(input);
    case AnalyticsPeriod.yearly:
      return _computeYearly(input);
  }
}

_ChartComputeResult _computeDaily(_ChartComputeInput input) {
  final currentByHour = List<double>.filled(24, 0);
  final previousByHour = List<double>.filled(24, 0);
  final countByHour = List<int>.filled(24, 0);

  for (final p in input.current) {
    final hour = DateTime.fromMillisecondsSinceEpoch(p.millis).hour;
    currentByHour[hour] += p.total;
    countByHour[hour] += 1;
  }
  for (final p in input.previous) {
    final hour = DateTime.fromMillisecondsSinceEpoch(p.millis).hour;
    previousByHour[hour] += p.total;
  }

  var busiestHour = -1;
  var busiestCount = 0;
  for (var h = 0; h < 24; h++) {
    if (countByHour[h] > busiestCount) {
      busiestCount = countByHour[h];
      busiestHour = h;
    }
  }

  return _ChartComputeResult(
    currentValues: currentByHour,
    previousValues: previousByHour,
    labels: [for (var h = 0; h < 24; h++) '$h'],
    busiestHourLabel: busiestHour == -1
        ? null
        : '${_formatHour(busiestHour)} - ${_formatHour((busiestHour + 1) % 24)}',
  );
}

_ChartComputeResult _computeMonthly(_ChartComputeInput input) {
  final now = DateTime.fromMillisecondsSinceEpoch(input.referenceMillis);
  final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
  final lastMonthRef = DateTime(now.year, now.month, 0);
  final daysInLastMonth = lastMonthRef.day;

  final currentByDay = List<double>.filled(daysInCurrentMonth, 0);
  final previousByDay = List<double>.filled(daysInLastMonth, 0);

  for (final p in input.current) {
    final day = DateTime.fromMillisecondsSinceEpoch(p.millis).day;
    currentByDay[day - 1] += p.total;
  }
  for (final p in input.previous) {
    final day = DateTime.fromMillisecondsSinceEpoch(p.millis).day;
    if (day - 1 < previousByDay.length) previousByDay[day - 1] += p.total;
  }

  return _ChartComputeResult(
    currentValues: currentByDay,
    previousValues: previousByDay,
    labels: [for (var d = 1; d <= daysInCurrentMonth; d++) '$d'],
  );
}

const _monthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

_ChartComputeResult _computeYearly(_ChartComputeInput input) {
  final currentByMonth = List<double>.filled(12, 0);
  final previousByMonth = List<double>.filled(12, 0);

  for (final p in input.current) {
    final month = DateTime.fromMillisecondsSinceEpoch(p.millis).month;
    currentByMonth[month - 1] += p.total;
  }
  for (final p in input.previous) {
    final month = DateTime.fromMillisecondsSinceEpoch(p.millis).month;
    previousByMonth[month - 1] += p.total;
  }

  return _ChartComputeResult(
    currentValues: currentByMonth,
    previousValues: previousByMonth,
    labels: _monthLabels,
  );
}

String _formatHour(int hour) {
  final period = hour < 12 ? 'AM' : 'PM';
  var displayHour = hour % 12;
  if (displayHour == 0) displayHour = 12;
  return '$displayHour $period';
}
