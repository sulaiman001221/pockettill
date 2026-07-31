import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/return_record.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../credit/date_range_sheet.dart';
import 'end_of_day_screen.dart';
import 'history_providers.dart';
import 'return_detail_screen.dart';
import 'sale_detail_screen.dart';

/// Sales History: a period-filtered summary card, filter tabs, and the
/// transaction list grouped by date. Sales and returns are merged into one
/// chronological list via [combinedHistoryProvider] - a return always shows
/// up as its own entry, never folded into the sale it came from.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final range = await Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SelectDateRangeScreen(
          initialRange: ref.read(historyCustomRangeProvider),
        ),
      ),
    );
    if (range != null) {
      ref.read(historyCustomRangeProvider.notifier).state = range;
      ref.read(historyFilterProvider.notifier).state = HistoryFilter.custom;
    }
  }

  /// Whether [DateTimeRange] spans exactly one calendar day - the End of
  /// Day Summary only makes sense for a single day's reconciliation, not a
  /// multi-day range.
  bool _isSingleDay(DateTimeRange range) {
    return range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;
  }

  void _openEndOfDay(BuildContext context, DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EndOfDayScreen(date: date)),
    );
  }

  Map<String, List<HistoryEntry>> _groupByDate(List<HistoryEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<HistoryEntry>>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.createdAt.year,
        entry.createdAt.month,
        entry.createdAt.day,
      );
      final String key;
      if (day == today) {
        key = 'TODAY';
      } else if (day == yesterday) {
        key = 'YESTERDAY';
      } else {
        key = DateFormat('d MMM yyyy').format(day).toUpperCase();
      }
      map.putIfAbsent(key, () => []).add(entry);
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(historyFilterProvider);
    final customRange = ref.watch(historyCustomRangeProvider);
    final salesAsync = ref.watch(filteredSalesProvider);
    final returnsAsync = ref.watch(filteredReturnsProvider);
    final combined = ref.watch(combinedHistoryProvider);
    final summary = ref.watch(historySummaryProvider);

    // Today, or a Custom range narrowed down to exactly one day - a
    // multi-day range has no single day to reconcile.
    final endOfDayDate = filter == HistoryFilter.today
        ? DateTime.now()
        : (filter == HistoryFilter.custom &&
                  customRange != null &&
                  _isSingleDay(customRange)
              ? customRange.start
              : null);

    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Sales History'),
      backgroundColor: AppTheme.background,
      bottomNavigationBar: endOfDayDate != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _openEndOfDay(context, endOfDayDate),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('End of Day Summary'),
                  ),
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(filteredSalesProvider.future),
          ref.refresh(filteredReturnsProvider.future),
        ]),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: _SummaryCard(
                  filterLabel: historyFilterLabel(filter),
                  summary: summary,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildFilterChips(context, ref, filter),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (salesAsync.isLoading || returnsAsync.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (salesAsync.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Could not load sales: ${salesAsync.error}'),
                ),
              )
            else if (returnsAsync.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Could not load returns: ${returnsAsync.error}'),
                ),
              )
            else
              _buildList(context, combined),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    WidgetRef ref,
    HistoryFilter filter,
  ) {
    Widget chip(String label, HistoryFilter value) {
      final isActive = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: value == HistoryFilter.custom
                ? () => _pickCustomRange(context, ref)
                : () => ref.read(historyFilterProvider.notifier).state = value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(9999),
                border: isActive ? null : Border.all(color: AppTheme.divider),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          chip('Today', HistoryFilter.today),
          chip('This Week', HistoryFilter.thisWeek),
          chip('This Month', HistoryFilter.thisMonth),
          chip('Custom', HistoryFilter.custom),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<HistoryEntry> entries) {
    if (entries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: AppTheme.iconBorder,
                ),
                const SizedBox(height: 16),
                Text(
                  'No sales or returns for this period',
                  style: AppTheme.mainTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different filter or date range',
                  style: AppTheme.bodySubtitle,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final grouped = _groupByDate(entries);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (final group in grouped.entries) ...[
            _DateHeader(
              label: group.key,
              total: group.value.fold<double>(0, (sum, e) {
                return switch (e) {
                  SaleHistoryEntry(:final sale) => sum + sale.total,
                  ReturnHistoryEntry(:final returnRecord) =>
                    sum + returnRecord.netMoneyMovement,
                };
              }),
            ),
            const SizedBox(height: 8),
            ...group.value.map(
              (entry) => switch (entry) {
                SaleHistoryEntry(:final sale) => _SaleListItem(
                  sale: sale,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SaleDetailScreen(sale: sale),
                    ),
                  ),
                ),
                ReturnHistoryEntry(:final returnRecord) => _ReturnListItem(
                  returnRecord: returnRecord,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReturnDetailScreen(returnRecord: returnRecord),
                    ),
                  ),
                ),
              },
            ),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.filterLabel, required this.summary});

  final String filterLabel;
  final HistorySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Total Revenue',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filterLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'R${summary.total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.description_outlined,
                  value: '${summary.count}',
                  label: 'Total Sales',
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.trending_up,
                  value: 'R${summary.averageSale.toStringAsFixed(2)}',
                  label: 'Avg. Sale',
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.payments_outlined,
                  value: '${summary.cashPercentage.toStringAsFixed(0)}%',
                  label: 'Cash',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label, required this.total});

  final String label;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            'R${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleListItem extends StatelessWidget {
  const _SaleListItem({required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('HH:mm').format(sale.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(timeText, style: AppTheme.bodySubtitle),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    paymentTypeIcon(sale.paymentType),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'R${sale.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _ItemCountLine(sale: sale),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        paymentTypeBadge(sale.paymentType),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.iconBorder,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A return's own row in the list - visually distinct from a sale (red
/// accent, return icon, "Return" badge) with its refund/deduction amount
/// shown as negative, so it's obvious at a glance that money went back.
class _ReturnListItem extends StatelessWidget {
  const _ReturnListItem({required this.returnRecord, required this.onTap});

  final ReturnRecord returnRecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('HH:mm').format(returnRecord.createdAt);
    final net = returnRecord.netMoneyMovement;
    final amountColor = net > 0
        ? AppTheme.syncGreen
        : (net < 0 ? AppTheme.logoutRed : AppTheme.textSecondary);
    final amountText = net > 0
        ? '+R${net.toStringAsFixed(2)}'
        : (net < 0
              ? '-R${(-net).toStringAsFixed(2)}'
              : 'R0.00');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(timeText, style: AppTheme.bodySubtitle),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.logoutRed.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_return_outlined,
                        color: AppTheme.logoutRed,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            amountText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: amountColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _ReturnSaleRefLine(returnRecord: returnRecord),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.logoutRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const Text(
                            '↩ Return',
                            style: TextStyle(
                              color: AppTheme.logoutRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.iconBorder,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Return for Sale #X" - fetched lazily since the list only needs it once
/// a tile actually renders, same as [_ItemCountLine].
class _ReturnSaleRefLine extends ConsumerWidget {
  const _ReturnSaleRefLine({required this.returnRecord});

  final ReturnRecord returnRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Sale?>(
      future: ref.read(saleRepositoryProvider).getByUuid(returnRecord.saleUuid),
      builder: (context, snapshot) {
        final sale = snapshot.data;
        return Text(
          sale != null ? 'Return for Sale #${sale.id}' : 'Return',
          style: AppTheme.bodySubtitle,
        );
      },
    );
  }
}

/// "X items · Sale #[id]" - fetched lazily since the list only needs it
/// once a tile actually renders.
class _ItemCountLine extends ConsumerWidget {
  const _ItemCountLine({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<SaleItem>>(
      future: ref.read(saleRepositoryProvider).getItemsForSale(sale.uuid),
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null) return const SizedBox.shrink();
        final count = items.fold<int>(0, (sum, i) => sum + i.quantity);
        return Text(
          '$count item${count == 1 ? '' : 's'} · Sale #${sale.id}',
          style: AppTheme.bodySubtitle,
        );
      },
    );
  }
}

/// Coloured-circle icon for a payment type - shared with [SaleDetailScreen].
Widget paymentTypeIcon(String paymentType, {double size = 40}) {
  final IconData icon;
  final Color color;
  switch (paymentType) {
    case 'cash':
      icon = Icons.payments_outlined;
      color = AppTheme.primary;
    case 'card':
      icon = Icons.credit_card;
      color = AppTheme.cardBlue;
    case 'credit':
      icon = Icons.person_outline;
      color = AppTheme.creditPurple;
    default:
      icon = Icons.receipt_long_outlined;
      color = AppTheme.iconBorder;
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: color, size: size * 0.5),
  );
}

/// Small "● Cash" / "▬ Card" / "↑ Credit" badge - shared with
/// [SaleDetailScreen].
Widget paymentTypeBadge(String paymentType) {
  final String glyph;
  final String label;
  final Color color;
  switch (paymentType) {
    case 'cash':
      glyph = '●';
      label = 'Cash';
      color = AppTheme.syncGreen;
    case 'card':
      glyph = '▬';
      label = 'Card';
      color = AppTheme.cardBlue;
    case 'credit':
      glyph = '↑';
      label = 'Credit';
      color = AppTheme.creditPurple;
    default:
      glyph = '●';
      label = paymentType;
      color = AppTheme.textSecondary;
  }
  return Text(
    '$glyph $label',
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
  );
}
