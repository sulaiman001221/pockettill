import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

Widget _detailRow(String label, String value) {
  return Row(
    children: [
      Text(label, style: AppTheme.bodySubtitle),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    ],
  );
}

/// Full detail of a single [CreditTransaction] - a credit purchase (with its
/// sale line items) or a repayment (with before/after balance).
class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.customerName,
  });

  final CreditTransaction transaction;
  final String customerName;

  @override
  ConsumerState<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends ConsumerState<TransactionDetailScreen> {
  Sale? _sale;
  List<SaleItem> _items = [];
  bool _loading = true;

  bool get _isCredit => widget.transaction.type == 'purchase';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = widget.transaction;
    if (_isCredit && t.saleUuid != null) {
      final repo = ref.read(saleRepositoryProvider);
      final sale = await repo.getByUuid(t.saleUuid!);
      final items = await repo.getItemsForSale(t.saleUuid!);
      if (!mounted) return;
      setState(() {
        _sale = sale;
        _items = items;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _printReceipt() async {
    final printer = ref.read(printerServiceProvider);
    final available = await printer.isPrinterAvailable();
    if (!mounted) return;

    if (!available) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No printer available')));
      return;
    }

    final t = widget.transaction;
    final storeConfig = await ref.read(storeConfigRepositoryProvider).get();
    await printer.printReceipt({
      'storeName': storeConfig?.storeName ?? 'My Store',
      'items': _items
          .map(
            (item) => {
              'name': item.productName,
              'quantity': item.quantity,
              'price': item.unitPrice,
            },
          )
          .toList(),
      'total': t.amount,
      'paymentMethod': _isCredit ? 'Credit' : (t.note ?? 'Cash'),
      'transactionNumber': _sale?.id ?? t.id,
      'date': t.createdAt,
      'customerName': widget.customerName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final color = _isCredit ? AppTheme.logoutRed : AppTheme.syncGreen;
    final icon = _isCredit ? Icons.arrow_upward : Icons.arrow_downward;
    final heading = _isCredit ? 'Credit Purchase' : 'Repayment';
    final dateText = DateFormat('dd/MM/yy, hh:mm a').format(t.createdAt);

    return Scaffold(
      appBar: _TransactionAppBar(onPrint: _printReceipt),
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: Text(heading, style: AppTheme.mainTitle)),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '${_isCredit ? '+' : '-'}R${t.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(child: Text(dateText, style: AppTheme.bodySubtitle)),
                const SizedBox(height: 24),
                _DetailsCard(
                  transaction: t,
                  sale: _sale,
                  customerName: widget.customerName,
                  isCredit: _isCredit,
                ),
                if (_isCredit) ...[
                  const SizedBox(height: 24),
                  const Text('ITEMS PURCHASED', style: _sectionLabelStyle),
                  const SizedBox(height: 12),
                  _ItemsCard(items: _items, total: t.amount),
                ] else ...[
                  const SizedBox(height: 24),
                  const Text('PAYMENT DETAILS', style: _sectionLabelStyle),
                  const SizedBox(height: 12),
                  _RepaymentDetailsCard(transaction: t),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _printReceipt,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print Receipt'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TransactionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TransactionAppBar({required this.onPrint});

  final VoidCallback onPrint;

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
              const Expanded(
                child: Center(
                  child: Text(
                    'Transaction Detail',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print_outlined, color: AppTheme.textPrimary),
                onPressed: onPrint,
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.transaction,
    required this.sale,
    required this.customerName,
    required this.isCredit,
  });

  final CreditTransaction transaction;
  final Sale? sale;
  final String customerName;
  final bool isCredit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          _detailRow('Transaction ID', '#${sale?.id ?? transaction.id}'),
          const SizedBox(height: 12),
          _detailRow('Type', isCredit ? 'Credit Purchase' : 'Repayment'),
          const SizedBox(height: 12),
          _detailRow('Customer', customerName),
          if (!isCredit) ...[
            const SizedBox(height: 12),
            _detailRow('Payment Method', transaction.note ?? 'Cash'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Status', style: AppTheme.bodySubtitle),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.syncGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text(
                  'Approved',
                  style: TextStyle(
                    color: AppTheme.syncGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items, required this.total});

  final List<SaleItem> items;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          for (final item in items) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${item.quantity} × R${item.unitPrice.toStringAsFixed(2)}',
                  style: AppTheme.bodySubtitle,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 70,
                  child: Text(
                    'R${item.subtotal.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'R${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepaymentDetailsCard extends StatelessWidget {
  const _RepaymentDetailsCard({required this.transaction});

  final CreditTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final before = transaction.balanceBefore;
    final after = transaction.balanceAfter;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          _detailRow('Amount Paid', 'R${transaction.amount.toStringAsFixed(2)}'),
          if (before != null) ...[
            const SizedBox(height: 12),
            _detailRow('Previous Balance', 'R${before.toStringAsFixed(2)}'),
          ],
          if (after != null) ...[
            const SizedBox(height: 12),
            _detailRow('New Balance', 'R${after.toStringAsFixed(2)}'),
          ],
          const SizedBox(height: 12),
          _detailRow('Payment Method', transaction.note ?? 'Cash'),
        ],
      ),
    );
  }
}
