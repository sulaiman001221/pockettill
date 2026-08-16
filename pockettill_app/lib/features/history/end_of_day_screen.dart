import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import 'history_providers.dart';

/// End-of-day till/card-machine reconciliation for a single calendar day -
/// reachable from Sales History for Today or for any single day picked via
/// the Custom filter. Laid out as a plain-language running total so a store
/// owner can see exactly where every rand in "Total Expected" comes from,
/// rather than a lump-sum figure they have to trust blindly. Has its own
/// print action for the Sunmi thermal printer (a no-op with a friendly
/// message on phones, matching [PrinterService]'s existing behaviour).
class EndOfDayScreen extends ConsumerStatefulWidget {
  const EndOfDayScreen({super.key, required this.date});

  /// The calendar day to summarise - only the year/month/day matter.
  final DateTime date;

  @override
  ConsumerState<EndOfDayScreen> createState() => _EndOfDayScreenState();
}

class _EndOfDayScreenState extends ConsumerState<EndOfDayScreen> {
  bool _printing = false;

  DateTime get _day =>
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  @override
  void initState() {
    super.initState();
    // endOfDaySummaryProvider is a plain (non-autoDispose) family, so it
    // keeps whatever it last computed for this date cached - without this,
    // reopening the page after processing a sale/return elsewhere would
    // keep showing yesterday's numbers for that date instead of refetching.
    // Deferred to after the first frame - invalidating a provider during
    // initState itself throws (the ProviderScope isn't reachable yet).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshEndOfDaySummary(ref, _day);
    });
  }

  Future<void> _print(EndOfDaySummary summary) async {
    final printer = ref.read(printerServiceProvider);
    final available = await printer.isPrinterAvailable();
    if (!mounted) return;

    if (!available) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No printer available')));
      return;
    }

    setState(() => _printing = true);
    final storeConfig = await ref.read(storeConfigRepositoryProvider).get();
    await printer.printEndOfDaySummary({
      'storeName': storeConfig?.storeName ?? 'My Store',
      'date': _day,
      'totalRevenue': summary.totalRevenue,
      'cashSales': summary.cashSales,
      'cardSales': summary.cardSales,
      'creditSales': summary.creditSales,
      'cashRepaymentsCollected': summary.cashRepaymentsCollected,
      'cardRepaymentsCollected': summary.cardRepaymentsCollected,
      'returnsNet': summary.returnsNet,
      'extraIncomeTotal': summary.extraIncomeTotal,
      'totalExpected': summary.totalExpected,
    });
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(endOfDaySummaryProvider(_day));
    final dateText = DateFormat('EEEE, d MMMM yyyy').format(_day);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _EndOfDayAppBar(
        dateText: dateText,
        refreshing: summaryAsync.isLoading,
        onRefresh: () => refreshEndOfDaySummary(ref, _day),
      ),
      body: SafeArea(
        bottom: false,
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Could not load this day\'s summary. Please try again.',
                style: AppTheme.bodySubtitle,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (summary) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _EndOfDayContent(summary: summary),
          ),
        ),
      ),
      // A fixed bar rather than part of the scrolling content - the print
      // button should always stay reachable regardless of how long the
      // calculation above grows or how far the owner has scrolled.
      bottomNavigationBar: summaryAsync.maybeWhen(
        data: (summary) => _PrintBar(
          printing: _printing,
          onPrint: () => _print(summary),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _EndOfDayAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _EndOfDayAppBar({
    required this.dateText,
    required this.refreshing,
    required this.onRefresh,
  });

  final String dateText;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'End of Day Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: AppTheme.textPrimary),
                onPressed: refreshing ? null : onRefresh,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

/// Fixed bottom bar holding the print button - kept outside the scrollable
/// content (see [EndOfDayScreen.build]) so it never scrolls out of reach.
class _PrintBar extends StatelessWidget {
  const _PrintBar({required this.printing, required this.onPrint});

  final bool printing;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 25),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: printing ? null : onPrint,
            icon: printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print_outlined),
            label: const Text('Print Summary'),
          ),
        ),
      ),
    );
  }
}

class _EndOfDayContent extends StatelessWidget {
  const _EndOfDayContent({required this.summary});

  final EndOfDaySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HighlightBox(
          label: 'TOTAL REVENUE',
          sublabel: 'All sales today, including credit sales not yet '
              'received',
          value: summary.totalRevenue,
        ),
        const SizedBox(height: 28),

        const Text('HOW TOTAL EXPECTED IS CALCULATED', style: _sectionLabelStyle),
        const SizedBox(height: 4),
        const Text(
          'Add up every row below and that\'s the money you should have '
          'in hand today',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),

        _CalculationRow(
          label: 'Cash Sales',
          sublabel: 'Money received in cash',
          amount: summary.cashSales,
          sign: _RowSign.plus,
        ),
        const SizedBox(height: 18),
        _CalculationRow(
          label: 'Card Sales',
          sublabel: 'Money received via card',
          amount: summary.cardSales,
          sign: _RowSign.plus,
        ),
        const SizedBox(height: 18),
        _PendingRow(amount: summary.creditSales),

        if (summary.extraIncomeTotal > 0) ...[
          const SizedBox(height: 18),
          _CalculationRow(
            label: 'Extra Income',
            sublabel: 'Airtime, electricity tokens, and other non-sale income',
            amount: summary.extraIncomeTotal,
            sign: _RowSign.plus,
          ),
        ],

        if (summary.hasReturns) ...[
          const SizedBox(height: 18),
          _CalculationRow(
            label: 'Returns',
            sublabel: summary.returnsNet < 0
                ? 'Refunds given to customers'
                : summary.returnsNet > 0
                    ? 'Extra paid by customers on exchanges'
                    : 'Refunds and exchanges balanced out today',
            amount: summary.returnsNet.abs(),
            sign: summary.returnsNet < 0 ? _RowSign.minus : _RowSign.plus,
          ),
        ],

        const SizedBox(height: 18),
        _CalculationRow(
          label: 'Cash Repayments',
          sublabel: 'Credit customers paying cash today',
          amount: summary.cashRepaymentsCollected,
          sign: _RowSign.plus,
        ),
        if (summary.cardRepaymentsCollected > 0) ...[
          const SizedBox(height: 18),
          _CalculationRow(
            label: 'Card Repayments',
            sublabel: 'Credit customers paying by card today',
            amount: summary.cardRepaymentsCollected,
            sign: _RowSign.plus,
          ),
        ],

        const SizedBox(height: 20),
        const Divider(color: AppTheme.divider, height: 1),
        const SizedBox(height: 20),

        _HighlightBox(
          label: 'TOTAL EXPECTED END OF DAY',
          sublabel: 'The total money the store actually received today - '
              'this excludes credit sales that have not been paid yet',
          value: summary.totalExpected,
          prominent: true,
        ),
      ],
    );
  }
}

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

enum _RowSign { plus, minus }

/// One step in the running-total calculation - label (with an optional
/// one-line explanation) on the left, a clearly-signed amount on the right.
/// Green for money coming in, red for money going out, so the direction is
/// obvious even before reading the sign.
class _CalculationRow extends StatelessWidget {
  const _CalculationRow({
    required this.label,
    this.sublabel,
    required this.amount,
    required this.sign,
  });

  final String label;
  final String? sublabel;
  final double amount;
  final _RowSign sign;

  @override
  Widget build(BuildContext context) {
    final isPlus = sign == _RowSign.plus;
    final color = isPlus ? AppTheme.syncGreen : AppTheme.logoutRed;
    final glyph = isPlus ? '+' : '-';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  sublabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$glyph R${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// The Credit Sales row - deliberately unsigned, since credit sales don't
/// affect what's actually in the till/card machine today. A clock icon and a
/// muted colour mark it as "pending" so it can't be mistaken for money
/// already counted in the total below.
class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.schedule,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Credit Sales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Not yet received - not included below',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'R${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }
}

/// Highlighted box for a headline figure - Total Revenue or Total Expected.
/// [prominent] makes Total Expected stand out as the page's final answer.
class _HighlightBox extends StatelessWidget {
  const _HighlightBox({
    required this.label,
    required this.sublabel,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String sublabel;
  final double value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: prominent
            ? AppTheme.primary
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: prominent ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'R${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: prominent ? Colors.white : AppTheme.primary,
              fontSize: prominent ? 30 : 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 12,
              color: prominent
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
