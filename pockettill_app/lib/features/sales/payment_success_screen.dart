import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/hardware/sound_service.dart';
import '../../main.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../stock/stock_screen.dart';
import '../stock/stock_ui.dart';
import 'cart_item.dart';
import 'sales_providers.dart';

/// A product sold in this transaction whose stock is now at or below its
/// low-stock threshold - surfaced so the cashier notices before it runs out
/// entirely, rather than finding out on the next sale attempt.
class LowStockAlert {
  const LowStockAlert({required this.productName, required this.stock});

  final String productName;
  final int stock;
}

/// Shown after a sale or credit repayment completes successfully. By
/// default clears the cart before returning to [ShellScreen] - pass
/// [onReturnHome] to go elsewhere instead (e.g. a credit repayment returns
/// to `CustomerDetailScreen`).
class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({
    super.key,
    this.cartItems = const [],
    required this.total,
    required this.paymentMethod,
    required this.saleNumber,
    required this.createdAt,
    this.customerName,
    this.onReturnHome,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.lowStockProducts = const [],
  });

  /// Empty for non-cart payments (e.g. a credit repayment).
  final List<CartItem> cartItems;
  final double total;

  /// Products just sold whose stock is now at or below their low-stock
  /// threshold - empty for non-cart payments, same as [cartItems].
  final List<LowStockAlert> lowStockProducts;

  /// 'cash' | 'card' | 'credit'.
  final String paymentMethod;
  final int saleNumber;
  final DateTime createdAt;

  /// Shown in place of the transaction ID row when this is a credit
  /// repayment rather than a cart sale.
  final String? customerName;

  /// Replaces the default clear-cart-and-return-to-Shell behaviour. Takes
  /// the current context since by the time this fires the screen that
  /// pushed this one may already be gone (replaced, not just covered).
  final void Function(BuildContext context)? onReturnHome;

  /// Replaces the default "Print Receipt" primary button (e.g. a credit
  /// repayment offers "Return to Customer" instead). Both must be provided
  /// together, or neither.
  final String? primaryActionLabel;
  final void Function(BuildContext context)? onPrimaryAction;

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    unawaited(SoundService.paymentSuccess());
    if (widget.lowStockProducts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) => _LowStockDialog(
            products: widget.lowStockProducts,
            onGoToStock: _goToStock,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _paymentLabel {
    switch (widget.paymentMethod) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'credit':
        return 'Credit';
      default:
        return widget.paymentMethod;
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

    final storeConfig = await ref.read(storeConfigRepositoryProvider).get();
    await printer.printReceipt({
      'storeName': storeConfig?.storeName ?? 'My Store',
      'items': widget.cartItems
          .map(
            (item) => {
              'name': productDisplayName(item.product),
              'quantity': item.quantity,
              'price': item.product.price,
            },
          )
          .toList(),
      'total': widget.total,
      'paymentMethod': _paymentLabel,
      'transactionNumber': widget.saleNumber,
      'date': widget.createdAt,
      if (widget.customerName != null) 'customerName': widget.customerName,
    });
  }

  void _returnHome() {
    if (widget.onReturnHome != null) {
      widget.onReturnHome!(context);
      return;
    }
    ref.read(salesNotifierProvider.notifier).clearCart();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _goToStock() {
    // Not a fixed-count pop - clear back to the shell first (regardless of
    // how this screen was reached), then push a fresh StockScreen, so this
    // always lands on Stock rather than wherever the stack happened to be.
    ref.read(salesNotifierProvider.notifier).clearCart();
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StockScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd/MM/yy, hh:mm a').format(widget.createdAt);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
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
              ),
              const SizedBox(height: 20),
              const Text('Payment Successful', style: AppTheme.mainTitle),
              const SizedBox(height: 8),
              const Text(
                'Transaction completed successfully',
                style: AppTheme.bodySubtitle,
              ),
              const SizedBox(height: 24),
              _DetailsCard(
                dateText: dateText,
                paymentLabel: _paymentLabel,
                saleNumber: widget.saleNumber,
                total: widget.total,
                customerName: widget.customerName,
              ),
              // A fixed gap, not Spacer - Spacer needs a bounded height to
              // distribute, which this Column no longer has now that it
              // sits inside a SingleChildScrollView.
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _printReceipt,
                  child: const Text('Print Receipt'),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.onPrimaryAction != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => widget.onPrimaryAction!(context),
                    child: Text(widget.primaryActionLabel!),
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
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _returnHome,
                    child: const Text('Return Home'),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.dateText,
    required this.paymentLabel,
    required this.saleNumber,
    required this.total,
    this.customerName,
  });

  final String dateText;
  final String paymentLabel;
  final int saleNumber;
  final double total;
  final String? customerName;

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
          const Text(
            'TOTAL AMOUNT',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'R${total.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 16),
          _DetailRow(icon: Icons.calendar_today, label: 'Date', value: dateText),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Icons.credit_card,
            label: 'Payment Method',
            value: paymentLabel,
          ),
          const SizedBox(height: 12),
          customerName != null
              ? _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Customer',
                  value: customerName!,
                )
              : _DetailRow(
                  icon: Icons.tag,
                  label: 'Transaction ID',
                  value: '#$saleNumber',
                ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 16,
                color: AppTheme.iconBorder,
              ),
              const SizedBox(width: 8),
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusDot(),
                    SizedBox(width: 4),
                    Text(
                      'Approved',
                      style: TextStyle(
                        color: AppTheme.syncGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppTheme.syncGreen,
        shape: BoxShape.circle,
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
}

/// Modal popup listing products this sale just pushed to (or past) their
/// low-stock threshold, with a shortcut to Stock to fix it immediately
/// rather than discovering it on the next sale attempt. A negative [stock]
/// already carries its own minus sign, so the label uses a colon rather
/// than a dash to avoid a double dash (e.g. "- -1 left").
class _LowStockDialog extends StatelessWidget {
  const _LowStockDialog({required this.products, required this.onGoToStock});

  final List<LowStockAlert> products;
  final VoidCallback onGoToStock;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.syncAmber,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Low Stock Alert',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    for (final product in products)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${product.productName}: ${product.stock} left',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.syncAmber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onGoToStock();
                    },
                    child: const Text(
                      'Go to Stock',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppTheme.iconBorder,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
