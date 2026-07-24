import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/quick_stock_update_sheet.dart';
import '../stock/stock_ui.dart';
import 'cart_item.dart';
import 'payment_success_screen.dart';
import 'sales_providers.dart';

enum _StockAlertAction { completeAnyway, updateStock, cancel }

const TextStyle _sectionLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: AppTheme.textSecondary,
  letterSpacing: 0.8,
);

/// Payment method selection and confirmation for the cart handed off from
/// [SalesScreen]. On success, hands the completed sale off to
/// [PaymentSuccessScreen].
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.cartTotal,
  });

  final List<CartItem> cartItems;
  final double cartTotal;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final int _saleNumber = 100 + Random().nextInt(900);
  final FocusNode _cashFocusNode = FocusNode(debugLabel: 'cashReceived');
  final FocusNode _customerSearchFocusNode = FocusNode(
    debugLabel: 'customerSearch',
  );
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final GlobalKey _customerSectionKey = GlobalKey();

  String _paymentMethod = 'cash';
  CreditCustomer? _selectedCustomer;
  List<CreditCustomer> _customers = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cashFocusNode.requestFocus();
    });
    _customerSearchFocusNode.addListener(_onCustomerSearchFocus);
    _loadCustomers();
  }

  /// The customer list sits below the search field, so once the keyboard is
  /// up the results are hidden behind it. Scroll the SELECT CUSTOMER section
  /// to the top of the viewport (after the keyboard animation settles) so
  /// the visible area above the keyboard shows the field plus results.
  void _onCustomerSearchFocus() {
    if (!_customerSearchFocusNode.hasFocus) return;
    // Deselect whoever was previously selected the moment the user starts
    // looking for someone else - otherwise a stale credit-limit warning for
    // the old selection lingers until a new customer is actually tapped.
    if (_selectedCustomer != null) setState(() => _selectedCustomer = null);
    Future.delayed(const Duration(milliseconds: 350), () {
      final ctx = _customerSectionKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  Future<void> _loadCustomers() async {
    final customers = await ref.read(creditRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() => _customers = customers);
  }

  @override
  void dispose() {
    _cashFocusNode.dispose();
    _customerSearchFocusNode.dispose();
    _cashController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  double get _cashReceived => double.tryParse(_cashController.text.trim()) ?? 0;

  /// Whether adding this sale to the selected customer's balance would put
  /// them over their credit limit (always false if they have no limit set).
  bool get _wouldExceedLimit {
    final customer = _selectedCustomer;
    final limit = customer?.creditLimit;
    if (customer == null || limit == null) return false;
    return (customer.balance + widget.cartTotal) > limit;
  }

  bool get _canConfirm {
    switch (_paymentMethod) {
      case 'cash':
        return _cashReceived >= widget.cartTotal;
      case 'card':
        return true;
      case 'credit':
        return _selectedCustomer != null && !_wouldExceedLimit;
      default:
        return false;
    }
  }

  String get _confirmLabel {
    switch (_paymentMethod) {
      case 'cash':
        return 'Confirm Payment';
      case 'card':
        // No card payment integration - this just records the sale, so it
        // reads the same as the cash confirmation rather than implying a
        // card machine hand-off is being triggered.
        return 'Confirm Payment';
      case 'credit':
        return 'Confirm Transaction';
      default:
        return 'Confirm';
    }
  }

  void _onSelectPaymentMethod(String method) {
    setState(() => _paymentMethod = method);
    if (method == 'cash') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cashFocusNode.requestFocus();
      });
    }
  }

  /// Cart items that would go negative if this sale completes now (checked
  /// against whatever stock value each item's [Product] was carrying when
  /// it was added to the cart - the same snapshot [SaleRepository
  /// .completeSale] itself deducts from).
  List<CartItem> _stockWarningItems() {
    return widget.cartItems
        .where((item) => item.product.stock - item.quantity < 0)
        .toList();
  }

  Future<void> _confirm() async {
    if (!_canConfirm || _submitting) return;

    final affected = _stockWarningItems();
    if (affected.isNotEmpty) {
      final action = await showModalBottomSheet<_StockAlertAction>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _StockAlertSheet(items: affected),
      );
      if (!mounted || action == null || action == _StockAlertAction.cancel) {
        return;
      }
      if (action == _StockAlertAction.updateStock) {
        await _updateStockForAffectedItems(affected);
        return;
      }
    }

    await _completeSale();
  }

  /// Shows the quick stock update sheet for each affected item in turn, then
  /// leaves the user back on this screen to review before tapping the
  /// confirm button again - it deliberately does not auto-complete the sale
  /// afterwards, since the corrected stock is worth a fresh look first.
  Future<void> _updateStockForAffectedItems(List<CartItem> affected) async {
    final repository = ref.read(productRepositoryProvider);
    for (final item in affected) {
      if (!mounted) return;
      final quantity = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        builder: (_) => QuickStockUpdateSheet(
          productName: productDisplayName(item.product),
          confirmLabel: 'Update Stock',
        ),
      );
      if (quantity == null || !mounted) continue;

      await repository.adjustStock(
        item.product.uuid,
        quantity - item.product.stock,
      );
      final updated = await repository.getByUuid(item.product.uuid);
      if (updated != null && mounted) {
        ref
            .read(salesNotifierProvider.notifier)
            .refreshCartItemProduct(updated);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock updated. Tap Confirm again to continue.'),
        ),
      );
    }
  }

  Future<void> _completeSale() async {
    setState(() => _submitting = true);

    try {
      final storeConfig = await ref.read(storeConfigRepositoryProvider).get();
      await ref
          .read(saleRepositoryProvider)
          .completeSale(
            cartItems: widget.cartItems
                .map(
                  (item) => {
                    'product': item.product,
                    'quantity': item.quantity,
                  },
                )
                .toList(),
            paymentType: _paymentMethod,
            customerId: _paymentMethod == 'credit'
                ? _selectedCustomer!.uuid
                : null,
            deviceId: storeConfig?.deviceId ?? '',
          );

      if (!mounted) return;
      // Pushing a new route doesn't reliably dismiss the keyboard on its
      // own - without this, a still-focused field (e.g. Cash Received)
      // stays open over PaymentSuccessScreen, shrinking its viewport
      // enough to overflow.
      FocusScope.of(context).unfocus();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            cartItems: widget.cartItems,
            total: widget.cartTotal,
            paymentMethod: _paymentMethod,
            saleNumber: _saleNumber,
            createdAt: DateTime.now(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not complete sale: $e'),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openNewCustomerSheet() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final customer = await showModalBottomSheet<CreditCustomer>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        var saving = false;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Customer', style: AppTheme.mainTitle),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                setSheetState(() => saving = true);
                                final newCustomer = CreditCustomer()
                                  ..uuid = ''
                                  ..name = nameController.text.trim()
                                  ..phone = phoneController.text.trim().isEmpty
                                      ? null
                                      : phoneController.text.trim()
                                  ..balance = 0;
                                await ref
                                    .read(creditRepositoryProvider)
                                    .saveCustomer(newCustomer);
                                if (!sheetContext.mounted) return;
                                Navigator.of(sheetContext).pop(newCustomer);
                              },
                        child: saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Customer'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (customer != null && mounted) {
      setState(() {
        _selectedCustomer = customer;
        _customers = [customer, ..._customers];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _CheckoutAppBar(saleNumber: _saleNumber),
      backgroundColor: AppTheme.background,
      // The confirm bar is meant to stay pinned to the bottom - without
      // this, the keyboard pushes the whole Scaffold body (confirm bar
      // included) up as it opens. The ListView above already scrolls, so
      // there's no content that actually needs the resize.
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        // Tapping anywhere outside a focused field (e.g. Cash Received)
        // dismisses its focus/cursor - without this, once focused it never
        // lets go, even on an outside tap.
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                // The body doesn't resize for the keyboard, so pad the list
                // bottom by the keyboard height instead - that's what lets
                // the customer search results scroll up into view while the
                // keyboard is open.
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  _TotalDueCard(total: widget.cartTotal),
                  const SizedBox(height: 20),
                  const Text('PAYMENT METHOD', style: _sectionLabelStyle),
                  const SizedBox(height: 12),
                  _PaymentMethodRow(
                    selected: _paymentMethod,
                    onSelect: _onSelectPaymentMethod,
                  ),
                  const SizedBox(height: 20),
                  _buildPaymentDetail(),
                ],
              ),
            ),
            _ConfirmBar(
              label: _confirmLabel,
              enabled: _canConfirm && !_submitting,
              submitting: _submitting,
              onPressed: _confirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetail() {
    switch (_paymentMethod) {
      case 'cash':
        return _buildCashDetail();
      case 'card':
        return _buildCardDetail();
      case 'credit':
        return _buildCreditDetail();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCashDetail() {
    final received = _cashReceived;
    final change = received - widget.cartTotal;
    final hasReceived = received > 0;
    final insufficient = hasReceived && change < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CASH PAYMENT', style: _sectionLabelStyle),
        const SizedBox(height: 12),
        TextField(
          controller: _cashController,
          focusNode: _cashFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Cash Received',
            prefixText: 'R ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (hasReceived) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (insufficient ? AppTheme.logoutRed : AppTheme.syncGreen)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  insufficient ? 'Insufficient Cash' : 'Change Due',
                  style: TextStyle(
                    color: insufficient
                        ? AppTheme.logoutRed
                        : AppTheme.syncGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'R${change.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    color: insufficient
                        ? AppTheme.logoutRed
                        : AppTheme.syncGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCardDetail() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CARD PAYMENT', style: _sectionLabelStyle),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Amount to Charge', style: AppTheme.bodySubtitle),
              const SizedBox(height: 4),
              Text(
                'R${widget.cartTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreditDetail() {
    final query = _customerSearchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _customers.take(5).toList()
        : _customers
              .where((c) => c.name.toLowerCase().contains(query))
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: _customerSectionKey,
          children: [
            const Text('SELECT CUSTOMER', style: _sectionLabelStyle),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.logoutRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  color: AppTheme.logoutRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _customerSearchController,
          focusNode: _customerSearchFocusNode,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search customer...',
          ),
          // Same reasoning as the focus listener above - a new search
          // shouldn't keep showing a warning for the previous selection.
          onChanged: (_) => setState(() => _selectedCustomer = null),
        ),
        const SizedBox(height: 12),
        ...filtered.map(
          (customer) => _CustomerTile(
            customer: customer,
            selected: _selectedCustomer?.uuid == customer.uuid,
            onTap: () => setState(() => _selectedCustomer = customer),
          ),
        ),
        if (_wouldExceedLimit) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.logoutRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.block,
                  color: AppTheme.logoutRed,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedCustomer!.name} would exceed their credit '
                    'limit of R${_selectedCustomer!.creditLimit!.toStringAsFixed(2)} '
                    'with this sale.',
                    style: const TextStyle(
                      color: AppTheme.logoutRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        InkWell(
          onTap: _openNewCustomerSheet,
          borderRadius: BorderRadius.circular(12),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.add, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'New Customer',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CheckoutAppBar({required this.saleNumber});

  final int saleNumber;

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
                    'Checkout',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$saleNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

class _TotalDueCard extends StatelessWidget {
  const _TotalDueCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Due',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'R${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaymentMethodCard(
            label: 'Cash',
            icon: Icons.payments_outlined,
            selected: selected == 'cash',
            onTap: () => onSelect('cash'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PaymentMethodCard(
            label: 'Card',
            icon: Icons.credit_card,
            selected: selected == 'card',
            onTap: () => onSelect('card'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PaymentMethodCard(
            label: 'Credit',
            icon: Icons.account_balance_wallet_outlined,
            selected: selected == 'credit',
            onTap: () => onSelect('credit'),
          ),
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

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.selected,
    required this.onTap,
  });

  final CreditCustomer customer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBalance = customer.balance > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.06)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            ProductAvatar(name: customer.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Total Credit: R${customer.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasBalance
                          ? AppTheme.syncAmber
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppTheme.primary : AppTheme.iconBorder,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.label,
    required this.enabled,
    required this.submitting,
    required this.onPressed,
  });

  final String label;
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
              : Text(label, style: AppTheme.buttonText),
        ),
      ),
    );
  }
}

class _StockAlertSheet extends StatelessWidget {
  const _StockAlertSheet({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              size: 48,
              color: AppTheme.syncAmber,
            ),
            const SizedBox(height: 12),
            const Text(
              'Stock Alert',
              textAlign: TextAlign.center,
              style: AppTheme.mainTitle,
            ),
            const SizedBox(height: 16),
            ...items.map((item) {
              final resulting = item.product.stock - item.quantity;
              final color = resulting < 0
                  ? AppTheme.logoutRed
                  : AppTheme.syncAmber;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        productDisplayName(item.product),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'will go to $resulting units',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(_StockAlertAction.completeAnyway),
                child: const Text('Complete Sale Anyway'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).pop(_StockAlertAction.updateStock),
                child: const Text('Update Stock First'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_StockAlertAction.cancel),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
