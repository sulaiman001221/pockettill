import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/credit_balance_display.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import 'add_customer_screen.dart';
import 'add_payment_screen.dart';
import 'date_range_sheet.dart';
import 'transaction_detail_screen.dart';

enum _HistoryFilter { today, thisWeek, thisMonth, custom }

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

/// A customer's outstanding balance, credit limit, and transaction history.
/// Loads its own data by [customerUuid] rather than taking a snapshot object,
/// so it always reflects the latest balance after a payment is recorded.
class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerUuid});

  final String customerUuid;

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  CreditCustomer? _customer;
  List<CreditTransaction> _transactions = [];
  bool _loading = true;
  _HistoryFilter _filter = _HistoryFilter.today;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(creditRepositoryProvider);
    final customer = await repo.getByUuid(widget.customerUuid);
    final transactions = customer == null
        ? <CreditTransaction>[]
        : await repo.getTransactionsForCustomer(customer.uuid, limit: 200);
    if (!mounted) return;
    setState(() {
      _customer = customer;
      _transactions = transactions;
      _loading = false;
    });
  }

  List<CreditTransaction> get _filteredTransactions {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day + 1);

    switch (_filter) {
      case _HistoryFilter.today:
        start = DateTime(now.year, now.month, now.day);
      case _HistoryFilter.thisWeek:
        // A rolling last-7-days window rather than the current Mon-Sun
        // calendar week - "this week" resetting to just today right after
        // Sunday flips into Monday was confusing (yesterday would vanish
        // from the filter even though it very obviously just happened).
        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 6));
      case _HistoryFilter.thisMonth:
        start = DateTime(now.year, now.month, 1);
      case _HistoryFilter.custom:
        if (_customRange == null) return _transactions;
        start = DateTime(
          _customRange!.start.year,
          _customRange!.start.month,
          _customRange!.start.day,
        );
        end = DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day + 1,
        );
    }

    return _transactions
        .where((t) => !t.createdAt.isBefore(start) && t.createdAt.isBefore(end))
        .toList();
  }

  Map<String, List<CreditTransaction>> _groupByDate(
    List<CreditTransaction> transactions,
  ) {
    final map = <String, List<CreditTransaction>>{};
    for (final t in transactions) {
      final key = DateFormat('d MMM yyyy').format(t.createdAt);
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  Future<void> _pickCustomRange() async {
    final range = await Navigator.of(context).push<DateTimeRange>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SelectDateRangeScreen(initialRange: _customRange),
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _customRange = range;
        _filter = _HistoryFilter.custom;
      });
    }
  }

  Future<void> _editCreditLimit() async {
    final customer = _customer;
    if (customer == null) return;

    final controller = TextEditingController(
      text: customer.creditLimit?.toStringAsFixed(2) ?? '',
    );
    // A limit below what the customer already owes would let them exceed
    // it the moment it's saved - the balance itself is the floor.
    final minLimit = customer.balance > 0 ? customer.balance : 0.0;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        String? error;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void save() {
              final text = controller.text.trim();
              if (text.isEmpty) {
                Navigator.of(sheetContext).pop('');
                return;
              }
              final parsed = double.tryParse(text);
              if (parsed == null) {
                setSheetState(() => error = 'Enter a valid amount');
                return;
              }
              if (parsed < minLimit) {
                setSheetState(
                  () => error =
                      "Can't be below the customer's current balance of "
                      '${formatCreditBalance(customer.balance)}',
                );
                return;
              }
              Navigator.of(sheetContext).pop(text);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Credit Limit', style: AppTheme.mainTitle),
                  if (minLimit > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Must be at least ${formatCreditBalance(minLimit)} - '
                      'what the customer already owes',
                      style: AppTheme.bodySubtitle,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixText: 'R ',
                      hintText: 'Leave empty for no limit',
                      errorText: error,
                    ),
                    onChanged: (_) {
                      if (error != null) setSheetState(() => error = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(onPressed: save, child: const Text('Save')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    final newLimit = result.isEmpty ? null : double.tryParse(result);
    await ref
        .read(creditRepositoryProvider)
        .updateCreditLimit(widget.customerUuid, newLimit);
    await _load();
  }

  /// Shows an amount (+ optional note) bottom sheet, following the same
  /// shape as [_editCreditLimit]'s. [validate] returns an error string to
  /// show inline, or null if the amount is acceptable. Returns null if the
  /// sheet was dismissed without confirming.
  Future<(double, String?)?> _showAmountSheet({
    required String title,
    String? helperText,
    required String? Function(double amount) validate,
  }) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showModalBottomSheet<(double, String?)>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        String? error;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void save() {
              final parsed = double.tryParse(amountController.text.trim());
              if (parsed == null || parsed <= 0) {
                setSheetState(() => error = 'Enter a valid amount');
                return;
              }
              final validationError = validate(parsed);
              if (validationError != null) {
                setSheetState(() => error = validationError);
                return;
              }
              final note = noteController.text.trim();
              Navigator.of(
                sheetContext,
              ).pop((parsed, note.isEmpty ? null : note));
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.mainTitle),
                  if (helperText != null) ...[
                    const SizedBox(height: 4),
                    Text(helperText, style: AppTheme.bodySubtitle),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixText: 'R ',
                      hintText: 'Amount',
                      errorText: error,
                    ),
                    onChanged: (_) {
                      if (error != null) setSheetState(() => error = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      hintText: 'Note (optional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(onPressed: save, child: const Text('Save')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _addManualCreditFlow() async {
    final customer = _customer;
    if (customer == null) return;

    final result = await _showAmountSheet(
      title: 'Add Credit Manually',
      helperText:
          'For credit given outside a sale (e.g. a phone order). Logged to '
          'the Risk Log.',
      validate: (_) => null,
    );
    if (result == null || !mounted) return;
    final (amount, note) = result;

    await ref
        .read(creditRepositoryProvider)
        .addManualCredit(
          customerUuid: customer.uuid,
          amount: amount,
          note: note,
        );
    await _load();
  }

  Future<void> _writeOffBalanceFlow() async {
    final customer = _customer;
    if (customer == null) return;

    final result = await _showAmountSheet(
      title: 'Write Off Balance',
      helperText:
          'Reduces the balance with no cash collected. Logged to the Risk '
          'Log.',
      validate: (amount) => amount > customer.balance
          ? "Can't exceed the current balance of "
                '${formatCreditBalance(customer.balance)}'
          : null,
    );
    if (result == null || !mounted) return;
    final (amount, note) = result;

    await ref
        .read(creditRepositoryProvider)
        .writeOffBalance(customerUuid: customer.uuid, amount: amount, note: note);
    await _load();
  }

  Future<void> _openAddPayment() async {
    final customer = _customer;
    if (customer == null) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddPaymentScreen(customer: customer)));
    await _load();
  }

  void _openTransactionDetail(CreditTransaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: transaction,
          customerName: _customer?.name ?? '',
        ),
      ),
    );
  }

  Color _limitColor(double balance, double limit) {
    final ratio = limit <= 0 ? 1.0 : balance / limit;
    if (ratio > 0.9) return AppTheme.logoutRed;
    if (ratio >= 0.7) return AppTheme.syncAmber;
    return AppTheme.syncGreen;
  }

  Future<void> _editCustomer() async {
    final customer = _customer;
    if (customer == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddCustomerScreen(existingCustomer: customer),
      ),
    );
    await _load();
  }

  void _deleteCustomer() {
    final customer = _customer;
    if (customer == null) return;

    showDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        message:
            'This will permanently delete ${customer.name} and all their '
            'transaction history.',
        confirmLabel: 'Delete',
        onConfirm: () {
          if (!mounted) return;
          // The actual delete (with its own Undo window) happens back on
          // CreditScreen, not here - this screen is about to be popped
          // since it's showing the very customer being removed.
          Navigator.of(context).pop(customer);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;

    return Scaffold(
      appBar: _CustomerDetailAppBar(
        title: customer?.name ?? 'Customer',
        onEdit: customer == null ? null : _editCustomer,
        onDelete: customer == null ? null : _deleteCustomer,
        onAddManualCredit: customer == null ? null : _addManualCreditFlow,
        onWriteOffBalance: customer == null ? null : _writeOffBalanceFlow,
      ),
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : customer == null
          ? const Center(child: Text('Customer not found'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _BalanceCard(customer: customer),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openAddPayment,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Payment'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCreditLimitSection(customer),
                  const SizedBox(height: 24),
                  const Text('TRANSACTION HISTORY', style: _sectionLabelStyle),
                  const SizedBox(height: 12),
                  _buildFilterChips(),
                  const SizedBox(height: 16),
                  _buildTransactionList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCreditLimitSection(CreditCustomer customer) {
    final limit = customer.creditLimit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('CREDIT LIMIT', style: _sectionLabelStyle),
              const Spacer(),
              InkWell(
                onTap: _editCreditLimit,
                child: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.iconBorder,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (limit == null)
            const Text('No limit set', style: AppTheme.bodySubtitle)
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: LinearProgressIndicator(
                value: limit > 0 ? (customer.balance / limit).clamp(0, 1) : 1,
                minHeight: 8,
                backgroundColor: AppTheme.background,
                color: _limitColor(customer.balance, limit),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Balance: ${formatCreditBalance(customer.balance)}',
                  style: AppTheme.bodySubtitle,
                ),
                const Spacer(),
                Text(
                  'Limit: R${limit.toStringAsFixed(2)}',
                  style: AppTheme.bodySubtitle,
                ),
              ],
            ),
            if (customer.balance >= limit) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.syncAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.syncAmber,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer cannot exceed this amount',
                        style: TextStyle(
                          color: AppTheme.syncAmber,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    Widget chip(String label, _HistoryFilter filter) {
      final isActive = _filter == filter;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(9999),
            onTap: filter == _HistoryFilter.custom
                ? _pickCustomRange
                : () => setState(() => _filter = filter),
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
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Today', _HistoryFilter.today),
          chip('This Week', _HistoryFilter.thisWeek),
          chip('This Month', _HistoryFilter.thisMonth),
          chip('Custom', _HistoryFilter.custom),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    final filtered = _filteredTransactions;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppTheme.iconBorder,
              ),
              const SizedBox(height: 12),
              Text(
                'No transactions for this period',
                style: AppTheme.mainTitle.copyWith(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Try a different filter, or add a payment above',
                style: AppTheme.bodySubtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupByDate(filtered);

    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          ...entry.value.map(
            (t) => _TransactionTile(
              transaction: t,
              onTap: () => _openTransactionDetail(t),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.customer});

  final CreditCustomer customer;

  @override
  Widget build(BuildContext context) {
    final owing = customer.balance > 0;
    final phone = customer.phone;
    final letter = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim()[0].toUpperCase();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatCreditBalance(customer.balance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (phone != null && phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  decoration: BoxDecoration(
                    color: owing ? AppTheme.syncAmber : AppTheme.syncGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  owing
                      ? 'Owing'
                      : (customer.balance < 0 ? 'In Credit' : 'Settled'),
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
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction, required this.onTap});

  final CreditTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCredit = transaction.type == 'purchase';
    final isReturn = transaction.type == 'return';
    final isManualCredit = transaction.type == 'manual_credit';
    final isWriteoff = transaction.type == 'writeoff';
    // A purchase and a manual credit always increase what's owed, and a
    // repayment/write-off always decreases it, but a return can go either
    // way - an exchange for a pricier item adds to the balance, while a
    // refund/cheaper exchange takes away from it - so for a return, the
    // transaction's own signed amount decides the direction instead of the
    // type alone.
    final increasesBalance =
        isCredit ||
        isManualCredit ||
        (isReturn && transaction.amount > 0);
    final color = increasesBalance ? AppTheme.logoutRed : AppTheme.syncGreen;
    final icon = increasesBalance ? Icons.arrow_upward : Icons.arrow_downward;
    final label = isCredit
        ? 'Credit'
        : (isReturn
              ? 'Return'
              : (isManualCredit
                    ? 'Manual Credit'
                    : (isWriteoff ? 'Write-Off' : 'Repayment')));
    final displayAmount = transaction.amount.abs();
    final dateText = DateFormat('d MMM yyyy').format(transaction.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(dateText, style: AppTheme.bodySubtitle),
                  if ((isCredit || isReturn) && transaction.saleUuid != null)
                    _SaleSummaryLine(saleUuid: transaction.saleUuid!)
                  else if ((transaction.note ?? '').isNotEmpty)
                    Text(transaction.note!, style: AppTheme.bodySubtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${increasesBalance ? '+' : '-'}R${displayAmount.toStringAsFixed(2)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    '● $label',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "X items · Sale #[id]" line for a credit-purchase transaction - fetched
/// lazily since the list only needs it once a tile actually renders.
class _SaleSummaryLine extends ConsumerWidget {
  const _SaleSummaryLine({required this.saleUuid});

  final String saleUuid;

  Future<(Sale?, List<SaleItem>)> _load(WidgetRef ref) async {
    final repo = ref.read(saleRepositoryProvider);
    final sale = await repo.getByUuid(saleUuid);
    final items = await repo.getItemsForSale(saleUuid);
    return (sale, items);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<(Sale?, List<SaleItem>)>(
      future: _load(ref),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final (sale, items) = data;
        final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
        return Text(
          '$itemCount item${itemCount == 1 ? '' : 's'} · Sale #${sale?.id ?? ''}',
          style: AppTheme.bodySubtitle,
        );
      },
    );
  }
}

/// App bar with an overflow menu (edit/delete) in place of the shared
/// [CustomAppBar]'s notification bell - there's nowhere else on this screen
/// as discoverable for those actions.
class _CustomerDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CustomerDetailAppBar({
    required this.title,
    required this.onEdit,
    required this.onDelete,
    required this.onAddManualCredit,
    required this.onWriteOffBalance,
  });

  final String title;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddManualCredit;
  final VoidCallback? onWriteOffBalance;

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit?.call();
                    case 'delete':
                      onDelete?.call();
                    case 'add_manual_credit':
                      onAddManualCredit?.call();
                    case 'write_off':
                      onWriteOffBalance?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit Customer'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_manual_credit',
                    child: ListTile(
                      leading: Icon(Icons.person_add_alt_outlined),
                      title: Text('Add Credit Manually'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'write_off',
                    child: ListTile(
                      leading: Icon(Icons.money_off),
                      title: Text('Write Off Balance'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: AppTheme.logoutRed),
                      title: Text(
                        'Delete Customer',
                        style: TextStyle(color: AppTheme.logoutRed),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
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
