import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import 'analytics_notifier.dart';
import 'analytics_providers.dart';

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

// The Payment Breakdown design uses this exact purple for Credit, distinct
// from the (differently-valued) credit colour used in the Sales History
// feature's own design - kept local rather than added to AppTheme to avoid
// two same-purpose constants with different values.
const Color _creditColor = Color(0xFF805AD5);

/// Store performance dashboard: a period-switchable sales trend chart with
/// headline stats, a payment breakdown, and a performance summary. The chart
/// section (which also feeds the stats and breakdown) and the performance
/// section load and retry independently, so one slow or broken repository
/// call never blanks out the whole screen.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsNotifierProvider);
    final notifier = ref.read(analyticsNotifierProvider.notifier);

    return Scaffold(
      appBar: const CustomAppBar(
        showMenuIcon: false,
        title: 'Analytics',
      ),
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: notifier.loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PeriodTabs(period: state.period, onSelect: notifier.setPeriod),
              const SizedBox(height: 16),
              _SalesTrendCard(state: state, onRetry: notifier.retryChart),
              const SizedBox(height: 16),
              _StatsRow(state: state),
              const SizedBox(height: 16),
              _PaymentBreakdownCard(state: state),
              const SizedBox(height: 16),
              _PerformanceSummaryCard(
                state: state,
                onRetry: notifier.retryPerformance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display label for the currently selected period, used by the trend
/// card's badge and the payment breakdown's header.
String _periodLabel(AnalyticsPeriod period) {
  switch (period) {
    case AnalyticsPeriod.daily:
      return 'This Week';
    case AnalyticsPeriod.monthly:
      return 'This Year';
    case AnalyticsPeriod.yearly:
      return 'Past 5 Years';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.logoutRed, size: 28),
          const SizedBox(height: 8),
          Text(message, style: AppTheme.bodySubtitle, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.period, required this.onSelect});

  final AnalyticsPeriod period;
  final ValueChanged<AnalyticsPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(child: _tab('Daily', AnalyticsPeriod.daily)),
          Expanded(child: _tab('Monthly', AnalyticsPeriod.monthly)),
          Expanded(child: _tab('Yearly', AnalyticsPeriod.yearly)),
        ],
      ),
    );
  }

  Widget _tab(String label, AnalyticsPeriod value) {
    final active = period == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.textSecondary,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _PeriodBadge extends StatelessWidget {
  const _PeriodBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTrendCard extends StatelessWidget {
  const _SalesTrendCard({required this.state, required this.onRetry});

  final AnalyticsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('SALES TREND', style: _sectionLabelStyle),
              const Spacer(),
              _PeriodBadge(label: _periodLabel(state.period)),
            ],
          ),
          const SizedBox(height: 16),
          if (state.chartError != null)
            _ErrorRetry(message: 'Could not load sales trend', onRetry: onRetry)
          else if (state.chartLoading || state.series == null)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _buildChart(state.series!, constraints.maxWidth),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Revenue (R) — vertical axis',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
            if (state.period == AnalyticsPeriod.daily &&
                state.busiestLabel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                      ),
                      children: [
                        const TextSpan(text: 'Busiest day: '),
                        TextSpan(
                          text: state.busiestLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// [maxWidth] is the chart's available plot width - used only to fall
  /// back from 12 monthly bars to the last 6 when there isn't roughly 30
  /// logical px per bar to keep month labels from overlapping.
  Widget _buildChart(ChartSeries series, double maxWidth) {
    var values = series.values;
    var labels = series.labels;
    if (values.length == 12 && maxWidth < 12 * 30.0) {
      values = values.sublist(6);
      labels = labels.sublist(6);
    }

    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 10.0 : maxValue * 1.15;
    final interval = maxY / 4;
    final barWidth = values.length > 8 ? 12.0 : 22.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppTheme.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                value >= 1000
                    ? '${(value / 1000).toStringAsFixed(1)}k'
                    : value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    labels[index],
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              'R${rod.toY.toStringAsFixed(2)}',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: AppTheme.primary,
                  width: barWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    // Total Sales delta: percent change vs previous period.
    String? totalDelta;
    var totalUp = true;
    if (!state.chartLoading && state.previousTotal > 0) {
      final pct =
          ((state.currentTotal - state.previousTotal) / state.previousTotal) *
          100;
      totalUp = pct >= 0;
      totalDelta = '${totalUp ? '+' : ''}${pct.toStringAsFixed(0)}%';
    }

    // Transactions delta: count difference vs previous period.
    String? transDelta;
    var transUp = true;
    if (!state.chartLoading &&
        (state.currentCount > 0 || state.previousCount > 0)) {
      final diff = state.currentCount - state.previousCount;
      transUp = diff >= 0;
      transDelta = '${transUp ? '+' : ''}$diff vs. prev';
    }

    // Avg sale delta: rand difference vs previous period.
    String? avgDelta;
    var avgUp = true;
    if (!state.chartLoading &&
        state.currentCount > 0 &&
        state.previousCount > 0) {
      final diff = state.currentAvgSale - state.previousAvgSale;
      avgUp = diff >= 0;
      avgDelta = '${avgUp ? '+' : '-'}R${diff.abs().toStringAsFixed(0)}';
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.insert_chart_outlined,
            label: 'Total Sales',
            value: 'R${state.currentTotal.toStringAsFixed(0)}',
            delta: totalDelta,
            deltaUp: totalUp,
            loading: state.chartLoading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long_outlined,
            label: 'Transactions',
            value: '${state.currentCount}',
            delta: transDelta,
            deltaUp: transUp,
            loading: state.chartLoading,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up,
            label: 'Avg. Sale',
            value: 'R${state.currentAvgSale.toStringAsFixed(0)}',
            delta: avgDelta,
            deltaUp: avgUp,
            loading: state.chartLoading,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaUp,
    required this.loading,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? delta;
  final bool deltaUp;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final deltaColor = deltaUp ? AppTheme.syncGreen : AppTheme.logoutRed;

    return _Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            loading ? '—' : value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (!loading && delta != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  deltaUp ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 11,
                  color: deltaColor,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    delta!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: deltaColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentBreakdownCard extends StatelessWidget {
  const _PaymentBreakdownCard({required this.state});

  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    final cash = state.cashAmount;
    final card = state.cardAmount;
    final credit = state.creditAmount;
    final total = cash + card + credit;

    final cashPct = total > 0 ? cash / total * 100 : 0.0;
    final cardPct = total > 0 ? card / total * 100 : 0.0;
    final creditPct = total > 0 ? credit / total * 100 : 0.0;

    // Centre label shows the dominant payment method.
    String centreLabel = 'Cash';
    double centrePct = cashPct;
    if (cardPct > centrePct) {
      centreLabel = 'Card';
      centrePct = cardPct;
    }
    if (creditPct > centrePct) {
      centreLabel = 'Credit';
      centrePct = creditPct;
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Payment Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                _periodLabel(state.period),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.chartLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 38,
                          startDegreeOffset: -90,
                          sections: total <= 0
                              ? [
                                  PieChartSectionData(
                                    value: 1,
                                    color: AppTheme.divider,
                                    showTitle: false,
                                    radius: 18,
                                  ),
                                ]
                              : [
                                  if (cash > 0)
                                    PieChartSectionData(
                                      value: cash,
                                      color: AppTheme.syncGreen,
                                      showTitle: false,
                                      radius: 18,
                                    ),
                                  if (card > 0)
                                    PieChartSectionData(
                                      value: card,
                                      color: AppTheme.primary,
                                      showTitle: false,
                                      radius: 18,
                                    ),
                                  if (credit > 0)
                                    PieChartSectionData(
                                      value: credit,
                                      color: _creditColor,
                                      showTitle: false,
                                      radius: 18,
                                    ),
                                ],
                        ),
                      ),
                      if (total > 0)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${centrePct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              centreLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else
                        const Text(
                          'No sales',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _LegendRow(
                        color: AppTheme.syncGreen,
                        label: 'Cash',
                        percent: cashPct,
                        amount: cash,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: AppTheme.divider, height: 1),
                      ),
                      _LegendRow(
                        color: AppTheme.primary,
                        label: 'Card',
                        percent: cardPct,
                        amount: card,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: AppTheme.divider, height: 1),
                      ),
                      _LegendRow(
                        color: _creditColor,
                        label: 'Credit',
                        percent: creditPct,
                        amount: credit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.percent,
    required this.amount,
  });

  final Color color;
  final String label;
  final double percent;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 13,
              ),
            ),
            Text(
              'R${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PerformanceSummaryCard extends StatelessWidget {
  const _PerformanceSummaryCard({required this.state, required this.onRetry});

  final AnalyticsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('PERFORMANCE SUMMARY', style: _sectionLabelStyle),
            ],
          ),
          const SizedBox(height: 16),
          if (state.performanceError != null)
            _ErrorRetry(
              message: 'Could not load performance data',
              onRetry: onRetry,
            )
          else if (state.performanceLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (state.bestDayLabel != null)
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Your best day this week was '),
                    TextSpan(
                      text: state.bestDayLabel,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' with '),
                    TextSpan(
                      text: 'R${state.bestDayAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' in revenue.'),
                  ],
                ),
              )
            else
              const Text(
                'No sales recorded this week yet.',
                style: AppTheme.bodySubtitle,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AVG SALE VALUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'R${state.avgSaleValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL TRANS.',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${state.totalTransactions}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.basketChangePercent != null) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final pct = state.basketChangePercent!;
                  final up = pct >= 0;
                  final color = up ? AppTheme.syncGreen : AppTheme.logoutRed;
                  return Row(
                    children: [
                      Icon(
                        up ? Icons.check_circle : Icons.error_outline,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                            children: [
                              const TextSpan(text: 'Average basket size is '),
                              TextSpan(
                                text:
                                    '${up ? 'up' : 'down'} '
                                    '${up ? '+' : ''}${pct.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const TextSpan(text: ' vs last week.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
