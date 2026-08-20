import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/risk_log.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../credit/date_range_sheet.dart';
import 'risk_log_providers.dart';

/// Risk Log: a period-filtered list of potentially suspicious stock/credit
/// activity - manual stock reductions, product deletions, price changes,
/// manual credit additions, and credit write-offs. Mirrors HistoryScreen's
/// Today / This Week / This Month / Custom filter tabs.
class RiskLogScreen extends ConsumerWidget {
  const RiskLogScreen({super.key});

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final range = await Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SelectDateRangeScreen(
          initialRange: ref.read(riskLogCustomRangeProvider),
        ),
      ),
    );
    if (range != null) {
      ref.read(riskLogCustomRangeProvider.notifier).state = range;
      ref.read(riskLogFilterProvider.notifier).state = RiskLogFilter.custom;
    }
  }

  Map<String, List<RiskLog>> _groupByDate(List<RiskLog> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<RiskLog>>{};
    for (final entry in entries) {
      final day = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
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
    final filter = ref.watch(riskLogFilterProvider);
    final entriesAsync = ref.watch(filteredRiskLogProvider);

    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Risk Log'),
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(filteredRiskLogProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildFilterChips(context, ref, filter)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            if (entriesAsync.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (entriesAsync.hasError)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Could not load risk log: ${entriesAsync.error}'),
                ),
              )
            else
              _buildList(entriesAsync.value ?? const []),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    WidgetRef ref,
    RiskLogFilter filter,
  ) {
    Widget chip(String label, RiskLogFilter value) {
      final isActive = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: value == RiskLogFilter.custom
                ? () => _pickCustomRange(context, ref)
                : () => ref.read(riskLogFilterProvider.notifier).state = value,
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
          chip('Today', RiskLogFilter.today),
          chip('This Week', RiskLogFilter.thisWeek),
          chip('This Month', RiskLogFilter.thisMonth),
          chip('Custom', RiskLogFilter.custom),
        ],
      ),
    );
  }

  Widget _buildList(List<RiskLog> entries) {
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
                  Icons.shield_outlined,
                  size: 64,
                  color: AppTheme.iconBorder,
                ),
                const SizedBox(height: 16),
                Text(
                  'No risk activity for this period',
                  style: AppTheme.mainTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Suspicious stock and credit changes will show up here',
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
            _DateHeader(label: group.key),
            const SizedBox(height: 8),
            ...group.value.map((entry) => _RiskLogTile(entry: entry)),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _RiskTypeInfo {
  const _RiskTypeInfo(this.icon, this.label, this.color);

  final IconData icon;
  final String label;
  final Color color;
}

_RiskTypeInfo _infoForType(String type) {
  switch (type) {
    case 'manual_stock_reduction':
      return const _RiskTypeInfo(
        Icons.trending_down,
        'Manual Stock Reduction',
        AppTheme.syncAmber,
      );
    case 'product_deleted':
      return const _RiskTypeInfo(
        Icons.delete_outline,
        'Product Deleted',
        AppTheme.logoutRed,
      );
    case 'price_changed':
      return const _RiskTypeInfo(
        Icons.sell_outlined,
        'Price Changed',
        AppTheme.cardBlue,
      );
    case 'manual_credit':
      return const _RiskTypeInfo(
        Icons.person_add_alt_outlined,
        'Manual Credit Added',
        AppTheme.creditPurple,
      );
    case 'credit_writeoff':
      return const _RiskTypeInfo(
        Icons.money_off,
        'Credit Written Off',
        AppTheme.logoutRed,
      );
    default:
      return const _RiskTypeInfo(
        Icons.warning_amber_outlined,
        'Risk Event',
        AppTheme.syncAmber,
      );
  }
}

class _RiskLogTile extends StatelessWidget {
  const _RiskLogTile({required this.entry});

  final RiskLog entry;

  @override
  Widget build(BuildContext context) {
    final info = _infoForType(entry.type);
    final timeText = DateFormat('HH:mm').format(entry.timestamp);
    final hasChange = entry.beforeValue != null || entry.afterValue != null;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(info.icon, color: info.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: info.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.entityName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (hasChange) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${entry.beforeValue ?? '-'} → ${entry.afterValue ?? '-'}',
                            style: AppTheme.bodySubtitle,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
