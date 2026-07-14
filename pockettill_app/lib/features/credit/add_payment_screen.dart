import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../sales/payment_success_screen.dart';
import '../stock/stock_ui.dart';

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

/// Records a payment against a customer's outstanding credit balance.
class AddPaymentScreen extends ConsumerStatefulWidget {
  const AddPaymentScreen({super.key, required this.customer});

  final CreditCustomer customer;

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final TextEditingController _amountToPayController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  final FocusNode _cashFocusNode = FocusNode(debugLabel: 'cashReceived');

  String _paymentMethod = 'cash';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountToPayController.text = widget.customer.balance.toStringAsFixed(2);
    _amountToPayController.addListener(_onChanged);
    _cashReceivedController.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cashFocusNode.requestFocus();
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountToPayController.dispose();
    _cashReceivedController.dispose();
    _cashFocusNode.dispose();
    super.dispose();
  }

  double get _balance => widget.customer.balance;
  double get _amountToPay =>
      double.tryParse(_amountToPayController.text.trim()) ?? 0;
  double get _cashReceived =>
      double.tryParse(_cashReceivedController.text.trim()) ?? 0;
  double get _change => _cashReceived - _amountToPay;
  double get _newBalance => (_balance - _amountToPay).clamp(0, double.infinity);

  bool get _canConfirm {
    if (_amountToPay <= 0 || _amountToPay > _balance) return false;
    if (_paymentMethod == 'cash') return _cashReceived >= _amountToPay;
    return true;
  }

  void _onSelectMethod(String method) {
    setState(() => _paymentMethod = method);
    if (method == 'cash') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cashFocusNode.requestFocus();
      });
    }
  }

  Future<void> _confirm() async {
    if (!_canConfirm || _submitting) return;
    setState(() => _submitting = true);

    try {
      await ref
          .read(creditRepositoryProvider)
          .recordRepayment(
            customerUuid: widget.customer.uuid,
            amount: _amountToPay,
            note: _paymentMethod == 'cash' ? 'Cash' : 'Card',
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            total: _amountToPay,
            paymentMethod: _paymentMethod,
            saleNumber: 100 + Random().nextInt(900),
            createdAt: DateTime.now(),
            customerName: widget.customer.name,
            // "Return to Customer" pops straight back to CustomerDetailScreen
            // (this screen replaced AddPaymentScreen via pushReplacement, so
            // it's directly underneath); "Return Home" keeps the default
            // clear-and-pop-to-Shell behaviour.
            primaryActionLabel: 'Return to Customer',
            onPrimaryAction: (ctx) => Navigator.of(ctx).pop(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not record payment: $e'),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tapping anywhere outside a text field dismisses its focus - without
      // this, once focused it never lets go, even on an outside tap.
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: const CustomAppBar(showMenuIcon: false, title: 'Add Payment'),
        backgroundColor: AppTheme.background,
        // The confirm bar and content above it don't leave room to shrink
        // when the keyboard appears; avoid resizing the body for it rather
        // than squeezing the confirm bar up right above the keyboard.
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                _CustomerHeader(customer: widget.customer),
                const SizedBox(height: 20),
                const Text('PAYMENT METHOD', style: _sectionLabelStyle),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodCard(
                        label: 'Cash',
                        icon: Icons.payments_outlined,
                        selected: _paymentMethod == 'cash',
                        onTap: () => _onSelectMethod('cash'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PaymentMethodCard(
                        label: 'Card',
                        icon: Icons.credit_card,
                        selected: _paymentMethod == 'card',
                        onTap: () => _onSelectMethod('card'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('PAYMENT DETAILS', style: _sectionLabelStyle),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountToPayController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount to Pay',
                    prefixText: 'R ',
                    helperText: 'Total outstanding balance',
                  ),
                ),
                if (_paymentMethod == 'cash') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cashReceivedController,
                    focusNode: _cashFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount Received',
                      prefixText: 'R ',
                      helperText: 'Cash handed by customer',
                    ),
                  ),
                  if (_cashReceived > _amountToPay) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.syncGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CHANGE DUE',
                                  style: TextStyle(
                                    color: AppTheme.syncGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  'Return to customer',
                                  style: TextStyle(
                                    color: AppTheme.syncGreen,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'R${_change.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppTheme.syncGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Proceed with card payment on your card machine',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildSummary(),
              ],
            ),
          ),
          _ConfirmBar(
            enabled: _canConfirm && !_submitting,
            submitting: _submitting,
            onPressed: _confirm,
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final settled = _newBalance <= 0;
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
          _summaryRow('Outstanding Balance', 'R${_balance.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          if (_paymentMethod == 'cash')
            _summaryRow(
              'Amount Received',
              'R${_cashReceived.toStringAsFixed(2)}',
            )
          else
            _summaryRow('Payment Method', 'Card'),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'New Balance After Payment',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'R${_newBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: settled ? AppTheme.syncGreen : AppTheme.syncAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
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
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({required this.customer});

  final CreditCustomer customer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProductAvatar(name: customer.name),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Paying for ${customer.name}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Current Balance',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            Text(
              'R${customer.balance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: selected ? AppTheme.primary : AppTheme.iconBorder,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.primary : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.enabled,
    required this.submitting,
    required this.onPressed,
  });

  final bool enabled;
  final bool submitting;
  final VoidCallback onPressed;

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
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          child: submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm Payment', style: AppTheme.buttonText),
        ),
      ),
    );
  }
}
