import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../main.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../stock/stock_screen.dart';
import 'process_return_screen.dart';

/// Shown after a return is successfully processed. Styled like
/// [PaymentSuccessScreen] - a checkmark, a details card, and navigation
/// options - but with an extra option, since "back to the sale this came
/// from" is a genuinely useful destination here.
class ReturnSuccessScreen extends ConsumerStatefulWidget {
  const ReturnSuccessScreen({
    super.key,
    required this.saleNumber,
    required this.items,
    required this.reason,
    required this.resolutionType,
    required this.stockAction,
    required this.customerOwes,
    required this.customerReceives,
    this.exchangeProductName,
  });

  final int saleNumber;

  /// Each returned [SaleItem] paired with how many units of it were
  /// returned in this transaction.
  final List<(SaleItem, int)> items;
  final String reason;
  final String resolutionType;
  final String stockAction;
  final double customerOwes;
  final double customerReceives;
  final String? exchangeProductName;

  @override
  ConsumerState<ReturnSuccessScreen> createState() =>
      _ReturnSuccessScreenState();
}

class _ReturnSuccessScreenState extends ConsumerState<ReturnSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _totalQuantity =>
      widget.items.fold<int>(0, (sum, entry) => sum + entry.$2);

  double get _itemsValue => widget.items.fold<double>(
    0,
    (sum, entry) => sum + entry.$1.unitPrice * entry.$2,
  );

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

    setState(() => _printing = true);
    final storeConfig = await ref.read(storeConfigRepositoryProvider).get();
    await printer.printReceipt({
      'storeName': storeConfig?.storeName ?? 'My Store',
      'items': widget.items
          .map(
            (entry) => {
              'name': entry.$1.productName,
              'quantity': entry.$2,
              'price': entry.$1.unitPrice,
            },
          )
          .toList(),
      'total': _itemsValue,
      'paymentMethod': 'Return - ${resolutionLabel(widget.resolutionType)}',
      'transactionNumber': widget.saleNumber,
      'date': DateTime.now(),
    });
    if (mounted) setState(() => _printing = false);
  }

  void _returnToSale() {
    // This screen replaced ProcessReturnScreen via pushReplacement, so
    // SaleDetailScreen is directly underneath - a plain pop lands there.
    Navigator.of(context).pop();
  }

  void _goToStock() {
    // Not a fixed-count pop - clear back to the shell, then push a fresh
    // StockScreen, so this lands on Stock regardless of how deep the return
    // flow's stack got.
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StockScreen()));
  }

  void _returnHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.syncGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.syncGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Return Processed', style: AppTheme.mainTitle),
              const SizedBox(height: 8),
              Text(
                '$_totalQuantity item${_totalQuantity == 1 ? '' : 's'} returned successfully.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySubtitle,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Just now · $time',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DetailsCard(
                items: widget.items,
                reason: widget.reason,
                resolutionType: widget.resolutionType,
                exchangeProductName: widget.exchangeProductName,
                customerOwes: widget.customerOwes,
                customerReceives: widget.customerReceives,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _printing ? null : _printReturnSlip,
                  icon: _printing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_outlined),
                  label: const Text('Print Receipt'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _returnToSale,
                  child: const Text('Return to Sale'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _goToStock,
                  child: const Text('Go to Stock'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _returnHome,
                child: const Text(
                  'Return Home',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.items,
    required this.reason,
    required this.resolutionType,
    required this.customerOwes,
    required this.customerReceives,
    this.exchangeProductName,
  });

  final List<(SaleItem, int)> items;
  final String reason;
  final String resolutionType;
  final double customerOwes;
  final double customerReceives;
  final String? exchangeProductName;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in items) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.$1.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('× ${entry.$2}', style: AppTheme.bodySubtitle),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.info_outline,
            label: 'Reason',
            value: reasonLabel(reason),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.assignment_return_outlined,
            label: 'Resolution',
            value: resolutionType == 'exchange' && exchangeProductName != null
                ? 'Exchanged for $exchangeProductName'
                : resolutionLabel(resolutionType),
          ),
          if (customerOwes > 0 || customerReceives > 0) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.payments_outlined,
              label: customerOwes > 0 ? 'Customer Pays' : 'Customer Receives',
              value:
                  'R${(customerOwes > 0 ? customerOwes : customerReceives).toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.iconBorder),
        const SizedBox(width: 8),
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
}
