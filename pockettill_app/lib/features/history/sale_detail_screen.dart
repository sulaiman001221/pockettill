import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
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

String _paymentLabel(String paymentType) {
  switch (paymentType) {
    case 'cash':
      return 'Cash';
    case 'card':
      return 'Card';
    case 'credit':
      return 'Credit';
    default:
      return paymentType;
  }
}

/// Full detail of a single [Sale] - its line items and a reprintable
/// receipt. Follows the same layout as Credit's TransactionDetailScreen.
class SaleDetailScreen extends ConsumerStatefulWidget {
  const SaleDetailScreen({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  List<SaleItem> _items = [];
  String? _customerName;
  bool _loading = true;

  bool get _isCredit => widget.sale.paymentType == 'credit';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sale = widget.sale;
    final items = await ref
        .read(saleRepositoryProvider)
        .getItemsForSale(sale.uuid);

    String? customerName;
    if (_isCredit && sale.customerId != null) {
      final customer = await ref
          .read(creditRepositoryProvider)
          .getByUuid(sale.customerId!);
      customerName = customer?.name;
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _customerName = customerName;
      _loading = false;
    });
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

    final sale = widget.sale;
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
      'total': sale.total,
      'paymentMethod': _paymentLabel(sale.paymentType),
      'transactionNumber': sale.id,
      'date': sale.createdAt,
      if (_customerName != null) 'customerName': _customerName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final color = switch (sale.paymentType) {
      'cash' => AppTheme.syncGreen,
      'card' => AppTheme.cardBlue,
      'credit' => AppTheme.creditPurple,
      _ => AppTheme.iconBorder,
    };
    final dateText = DateFormat('dd/MM/yy, hh:mm a').format(sale.createdAt);
    final itemCount = _items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Scaffold(
      appBar: _SaleDetailAppBar(onPrint: _printReceipt),
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
                    child: Icon(
                      switch (sale.paymentType) {
                        'card' => Icons.credit_card,
                        'credit' => Icons.person_outline,
                        _ => Icons.payments_outlined,
                      },
                      color: color,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('Sale #${sale.id}', style: AppTheme.mainTitle),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'R${sale.total.toStringAsFixed(2)}',
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
                  sale: sale,
                  customerName: _customerName,
                  itemCount: itemCount,
                ),
                const SizedBox(height: 24),
                const Text('ITEMS PURCHASED', style: _sectionLabelStyle),
                const SizedBox(height: 12),
                _ItemsCard(items: _items, total: sale.total),
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

class _SaleDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SaleDetailAppBar({required this.onPrint});

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
                    'Sale Detail',
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
    required this.sale,
    required this.customerName,
    required this.itemCount,
  });

  final Sale sale;
  final String? customerName;
  final int itemCount;

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
          _detailRow('Transaction ID', '#${sale.id}'),
          const SizedBox(height: 12),
          _detailRow(
            'Date',
            DateFormat('dd/MM/yy, hh:mm a').format(sale.createdAt),
          ),
          const SizedBox(height: 12),
          _detailRow('Payment Method', _paymentLabel(sale.paymentType)),
          if (customerName != null) ...[
            const SizedBox(height: 12),
            _detailRow('Customer', customerName!),
          ],
          const SizedBox(height: 12),
          _detailRow('Items Count', '$itemCount items'),
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
                  'Completed',
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
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
                      color: AppTheme.primary,
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
                'TOTAL',
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
