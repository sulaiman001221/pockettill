import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../shared/models/return_item.dart';
import '../../shared/models/return_record.dart';
import '../../shared/models/sale.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import 'process_return_screen.dart' show reasonLabel, resolutionLabel;

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

/// Matches how the return's amount is displayed in Sales History's list -
/// the net money that actually moved, not the returned goods' value.
String _netAmountText(double net) {
  if (net > 0) return '+R${net.toStringAsFixed(2)}';
  if (net < 0) return '-R${(-net).toStringAsFixed(2)}';
  return 'R0.00';
}

Color _netAmountColor(double net) {
  if (net > 0) return AppTheme.syncGreen;
  if (net < 0) return AppTheme.logoutRed;
  return AppTheme.textSecondary;
}

Widget _detailRow(String label, String value) {
  return Row(
    children: [
      Text(label, style: AppTheme.bodySubtitle),
      const Spacer(),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    ],
  );
}

/// Full detail of a single [ReturnRecord] - its returned items and a
/// reprintable return slip. Reached by tapping a return's own entry in
/// Sales History.
class ReturnDetailScreen extends ConsumerStatefulWidget {
  const ReturnDetailScreen({super.key, required this.returnRecord});

  final ReturnRecord returnRecord;

  @override
  ConsumerState<ReturnDetailScreen> createState() =>
      _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends ConsumerState<ReturnDetailScreen> {
  List<ReturnItem> _items = [];
  Sale? _sale;
  String? _customerName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = widget.returnRecord;
    final items = await ref
        .read(returnRepositoryProvider)
        .getItemsForReturn(r.uuid);
    final sale = await ref.read(saleRepositoryProvider).getByUuid(r.saleUuid);

    String? customerName;
    if (r.customerId != null) {
      final customer = await ref
          .read(creditRepositoryProvider)
          .getByUuid(r.customerId!);
      customerName = customer?.name;
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _sale = sale;
      _customerName = customerName;
      _loading = false;
    });
  }

  Future<void> _printReturnSlip() async {
    final printer = ref.read(printerServiceProvider);
    final available = await printer.isPrinterAvailable();
    if (!mounted) return;

    if (!available) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No printer available')));
      return;
    }

    final r = widget.returnRecord;
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
      'total': r.itemsValue,
      'paymentMethod': 'Return - ${resolutionLabel(r.resolutionType)}',
      'transactionNumber': _sale?.id ?? r.uuid.substring(0, 8),
      'date': r.createdAt,
      if (_customerName != null) 'customerName': _customerName,
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.returnRecord;
    final dateText = DateFormat('dd/MM/yy, hh:mm a').format(r.createdAt);
    final itemCount = _items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Scaffold(
      appBar: _ReturnDetailAppBar(onPrint: _printReturnSlip),
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
                      color: AppTheme.logoutRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_return_outlined,
                      color: AppTheme.logoutRed,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _sale != null ? 'Return for Sale #${_sale!.id}' : 'Return',
                    style: AppTheme.mainTitle,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _netAmountText(r.netMoneyMovement),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _netAmountColor(r.netMoneyMovement),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(child: Text(dateText, style: AppTheme.bodySubtitle)),
                const SizedBox(height: 24),
                _DetailsCard(
                  returnRecord: r,
                  customerName: _customerName,
                  itemCount: itemCount,
                ),
                const SizedBox(height: 24),
                const Text('ITEMS RETURNED', style: _sectionLabelStyle),
                const SizedBox(height: 12),
                _ItemsCard(items: _items, total: r.itemsValue),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _printReturnSlip,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print Return Slip'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ReturnDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReturnDetailAppBar({required this.onPrint});

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
                    'Return Detail',
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
    required this.returnRecord,
    required this.customerName,
    required this.itemCount,
  });

  final ReturnRecord returnRecord;
  final String? customerName;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final r = returnRecord;
    final hasMoney = r.customerOwes > 0 || r.customerReceives > 0;

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
          _detailRow('Reason', reasonLabel(r.reason)),
          const SizedBox(height: 12),
          _detailRow(
            'Stock Impact',
            r.stockAction == 'write_off' ? 'Written off' : 'Added back to stock',
          ),
          const SizedBox(height: 12),
          _detailRow(
            'Resolution',
            r.resolutionType == 'exchange' && r.exchangeProductName != null
                ? 'Exchanged for ${r.exchangeProductName}'
                : resolutionLabel(r.resolutionType),
          ),
          if (customerName != null) ...[
            const SizedBox(height: 12),
            _detailRow('Customer', customerName!),
          ],
          if (hasMoney) ...[
            const SizedBox(height: 12),
            _detailRow(
              r.customerOwes > 0 ? 'Customer Paid' : 'Customer Received',
              'R${(r.customerOwes > 0 ? r.customerOwes : r.customerReceives).toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: 12),
          _detailRow('Items Count', '$itemCount items'),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items, required this.total});

  final List<ReturnItem> items;
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
                    'R${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.logoutRed,
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
                'TOTAL RETURNED',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '-R${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.logoutRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
