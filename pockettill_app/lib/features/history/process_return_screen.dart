import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/product.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/credit_balance_display.dart';
import '../../shared/utils/friendly_error.dart';
import '../stock/barcode_scanner_screen.dart';
import '../stock/stock_ui.dart';
import 'return_success_screen.dart';

enum _ReturnStep { selectItems, reason, stockAction, resolution, summary }

String reasonLabel(String reason) => switch (reason) {
  'expired_broken' => 'Expired or Broken',
  'wrong_item' => 'Wrong Item',
  'change_of_mind' => 'Change of Mind',
  _ => reason,
};

String resolutionLabel(String resolution) => switch (resolution) {
  'refund' => 'Refund',
  'exchange' => 'Exchange',
  'store_credit' => 'Store Credit',
  _ => resolution,
};

/// Where a return's money actually goes: some combination of cash over the
/// counter and a change to a credit customer's balance. At most one of
/// [cashFromCustomer]/[cashToCustomer] is ever non-zero (money only ever
/// flows one direction per return), and [balanceDelta] can be paired with
/// either when a balance can only partly absorb the amount.
class _MoneyOutcome {
  const _MoneyOutcome({
    this.cashFromCustomer = 0,
    this.cashToCustomer = 0,
    this.balanceDelta = 0,
  });

  /// Cash the customer pays over the counter (an exchange for a pricier
  /// item, settled outside any credit balance).
  final double cashFromCustomer;

  /// Cash handed to the customer (a refund, or an exchange for a cheaper
  /// item, settled outside any credit balance - or whatever a credit
  /// balance couldn't fully absorb).
  final double cashToCustomer;

  /// Change to a credit customer's balance: positive means they now owe
  /// more, negative means they owe less (or, if it goes below zero, that
  /// the store now owes them - store credit or an over-refund).
  final double balanceDelta;
}

/// Walks a cashier through returning one or more items from [sale]: which
/// items, why, what happens to the returned stock, and what the customer
/// gets back - then processes everything as one operation via
/// [ReturnRepository.processReturn].
class ProcessReturnScreen extends ConsumerStatefulWidget {
  const ProcessReturnScreen({super.key, required this.sale});

  final Sale sale;

  @override
  ConsumerState<ProcessReturnScreen> createState() =>
      _ProcessReturnScreenState();
}

class _ProcessReturnScreenState extends ConsumerState<ProcessReturnScreen> {
  bool _loading = true;
  List<SaleItem> _saleItems = [];
  Map<String, int> _alreadyReturned = {};

  // The credit customer tied to the ORIGINAL sale, if it was a credit sale -
  // needed to show the balance-impact preview for a refund against it.
  // Distinct from _selectedCustomer, which is whoever the cashier picks to
  // receive store credit (not necessarily the same person).
  CreditCustomer? _saleCustomer;

  _ReturnStep _step = _ReturnStep.selectItems;
  final Map<String, int> _selectedQty = {};

  String? _reason;
  String? _stockAction;
  String? _resolutionType;

  Product? _exchangeProduct;
  CreditCustomer? _selectedCustomer;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ref
        .read(saleRepositoryProvider)
        .getItemsForSale(widget.sale.uuid);
    final returned = await ref
        .read(returnRepositoryProvider)
        .getReturnedQuantities(widget.sale.uuid);

    CreditCustomer? saleCustomer;
    if (widget.sale.paymentType == 'credit' && widget.sale.customerId != null) {
      saleCustomer = await ref
          .read(creditRepositoryProvider)
          .getByUuid(widget.sale.customerId!);
    }

    if (!mounted) return;
    setState(() {
      _saleItems = items;
      _alreadyReturned = returned;
      _saleCustomer = saleCustomer;
      _loading = false;
    });
  }

  int _remainingFor(SaleItem item) =>
      item.quantity - (_alreadyReturned[item.productUuid] ?? 0);

  List<SaleItem> get _returnableItems =>
      _saleItems.where((item) => _remainingFor(item) > 0).toList();

  List<SaleItem> get _chosenItems => _returnableItems
      .where((item) => (_selectedQty[item.productUuid] ?? 0) > 0)
      .toList();

  double get _itemsValue {
    var total = 0.0;
    for (final item in _chosenItems) {
      total += item.unitPrice * (_selectedQty[item.productUuid] ?? 0);
    }
    return total;
  }

  bool get _hasSelection => _chosenItems.isNotEmpty;

  /// The step sequence depends on [_reason] - "what happens to the stock" is
  /// only ever asked when it's genuinely a choice (Expired/Broken); Wrong
  /// Item and Change of Mind always restock automatically.
  List<_ReturnStep> get _stepOrder {
    return [
      _ReturnStep.selectItems,
      _ReturnStep.reason,
      if (_reason == 'expired_broken') _ReturnStep.stockAction,
      _ReturnStep.resolution,
      _ReturnStep.summary,
    ];
  }

  bool get _canContinue {
    switch (_step) {
      case _ReturnStep.selectItems:
        return _hasSelection;
      case _ReturnStep.reason:
        return _reason != null;
      case _ReturnStep.stockAction:
        return _stockAction != null;
      case _ReturnStep.resolution:
        if (_resolutionType == null) return false;
        if (_resolutionType == 'exchange') return _exchangeProduct != null;
        if (_resolutionType == 'store_credit') {
          // Store credit only makes sense for a customer who doesn't
          // already owe money - see _MoneyOutcome's class doc.
          return _selectedCustomer != null && _selectedCustomer!.balance <= 0;
        }
        return true;
      case _ReturnStep.summary:
        return true;
    }
  }

  void _selectReason(String reason) {
    setState(() {
      _reason = reason;
      // Wrong Item / Change of Mind: the product itself is fine, so it
      // always goes back to stock automatically - no separate choice to
      // make, unlike Expired/Broken.
      _stockAction = reason == 'expired_broken' ? null : 'restock';
    });
  }

  void _selectResolution(String resolution) {
    setState(() {
      _resolutionType = resolution;
      if (resolution == 'store_credit' &&
          _selectedCustomer == null &&
          widget.sale.paymentType == 'credit') {
        // Pre-select the sale's own credit customer as the default, per
        // spec - the cashier can still change it.
        _prefillSaleCustomer();
      }
    });
  }

  Future<void> _prefillSaleCustomer() async {
    final customerId = widget.sale.customerId;
    if (customerId == null) return;
    final customer = await ref
        .read(creditRepositoryProvider)
        .getByUuid(customerId);
    if (!mounted || customer == null) return;
    setState(() => _selectedCustomer = customer);
  }

  void _goNext() {
    if (!_canContinue) return;
    final order = _stepOrder;
    final index = order.indexOf(_step);
    if (index < order.length - 1) {
      setState(() => _step = order[index + 1]);
    }
  }

  void _goBack() {
    final order = _stepOrder;
    final index = order.indexOf(_step);
    if (index > 0) {
      setState(() => _step = order[index - 1]);
    } else {
      Navigator.of(context).pop();
    }
  }

  double get _replacementPrice => _exchangeProduct?.price ?? 0;

  /// Positive: customer owes this amount. Negative: customer is owed this
  /// amount back. Zero: nothing changes hands.
  double get _exchangeDifference => _replacementPrice - _itemsValue;

  /// The credit customer whose balance a refund or exchange affects - the
  /// sale's own customer, since only a credit sale's own tab is ever
  /// adjusted this way (store credit is handled separately via
  /// _selectedCustomer, a deliberately different pick). Null for a cash/card
  /// sale, where a refund or exchange is always settled at the counter.
  CreditCustomer? get _balanceCustomer {
    if (widget.sale.paymentType != 'credit') return null;
    if (_resolutionType == 'refund' || _resolutionType == 'exchange') {
      return _saleCustomer;
    }
    return null;
  }

  /// The credit customer whose balance this return affects - the sale's own
  /// customer for a refund/exchange against a credit sale, or whoever was
  /// picked for store credit. Null for a cash/card refund or an exchange
  /// settled at the counter, neither of which touch a credit balance.
  String? get _customerIdForResolution {
    if (_resolutionType == 'store_credit') return _selectedCustomer?.uuid;
    return _balanceCustomer?.uuid;
  }

  /// Where the money for the current resolution actually goes: cash handed
  /// over the counter versus a change to a credit customer's balance. Follows
  /// the same rules in every case - if the customer already owes money, the
  /// return settles against that balance first (never below zero); only
  /// whatever the balance can't absorb (or the whole amount, if there's
  /// nothing owing to absorb it into) is ever cash.
  _MoneyOutcome get _moneyOutcome {
    switch (_resolutionType) {
      case 'refund':
        final customer = _balanceCustomer;
        if (customer == null || customer.balance <= 0) {
          return _MoneyOutcome(cashToCustomer: _itemsValue);
        }
        final balance = customer.balance;
        if (_itemsValue <= balance) {
          return _MoneyOutcome(balanceDelta: -_itemsValue);
        }
        return _MoneyOutcome(
          cashToCustomer: _itemsValue - balance,
          balanceDelta: -balance,
        );

      case 'exchange':
        final diff = _exchangeDifference;
        if (diff == 0) return const _MoneyOutcome();
        final customer = _balanceCustomer;
        if (customer == null || customer.balance <= 0) {
          return diff > 0
              ? _MoneyOutcome(cashFromCustomer: diff)
              : _MoneyOutcome(cashToCustomer: -diff);
        }
        final balance = customer.balance;
        if (diff > 0) return _MoneyOutcome(balanceDelta: diff);
        final owed = -diff;
        if (owed <= balance) return _MoneyOutcome(balanceDelta: -owed);
        return _MoneyOutcome(
          cashToCustomer: owed - balance,
          balanceDelta: -balance,
        );

      case 'store_credit':
        return _MoneyOutcome(balanceDelta: -_itemsValue);

      default:
        return const _MoneyOutcome();
    }
  }

  /// Gross value that moved this return, cash or balance combined - what
  /// Sales History's list/summary total, and this return's own receipt,
  /// should show. Unaffected by whether the amount actually landed as cash
  /// or against a credit balance.
  double get _customerOwes {
    final outcome = _moneyOutcome;
    return outcome.cashFromCustomer +
        (outcome.balanceDelta > 0 ? outcome.balanceDelta : 0);
  }

  double get _customerReceives {
    final outcome = _moneyOutcome;
    return outcome.cashToCustomer +
        (outcome.balanceDelta < 0 ? -outcome.balanceDelta : 0);
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final storeConfig = await ref.read(storeConfigRepositoryProvider).get();
      final items = _chosenItems
          .map(
            (item) => {
              'saleItem': item,
              'quantity': _selectedQty[item.productUuid]!,
            },
          )
          .toList();

      final outcome = _moneyOutcome;
      await ref
          .read(returnRepositoryProvider)
          .processReturn(
            sale: widget.sale,
            items: items,
            reason: _reason!,
            stockAction: _stockAction!,
            resolutionType: _resolutionType!,
            itemsValue: _itemsValue,
            customerOwes: _customerOwes,
            customerReceives: _customerReceives,
            cashPaidToCustomer: outcome.cashToCustomer,
            balanceDelta: outcome.balanceDelta,
            customerId: _customerIdForResolution,
            exchangeProduct: _exchangeProduct,
            deviceId: storeConfig?.deviceId ?? '',
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReturnSuccessScreen(
            saleNumber: widget.sale.id,
            items: _chosenItems
                .map(
                  (item) => (item, _selectedQty[item.productUuid] ?? 0),
                )
                .toList(),
            reason: _reason!,
            resolutionType: _resolutionType!,
            stockAction: _stockAction!,
            customerOwes: _customerOwes,
            customerReceives: _customerReceives,
            exchangeProductName: _exchangeProduct != null
                ? productDisplayName(_exchangeProduct!)
                : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              e,
              fallback: 'Could not process the return. Please try again or '
                  'contact support.',
            ),
          ),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        appBar: _ReturnAppBar(
          stepIndex: _stepOrder.indexOf(_step),
          stepCount: _stepOrder.length,
          onBack: _goBack,
        ),
        backgroundColor: AppTheme.background,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildStep(),
        bottomNavigationBar: _loading ? null : _buildBottomBar(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _ReturnStep.selectItems:
        return _buildSelectItems();
      case _ReturnStep.reason:
        return _buildReason();
      case _ReturnStep.stockAction:
        return _buildStockAction();
      case _ReturnStep.resolution:
        return _buildResolution();
      case _ReturnStep.summary:
        return _buildSummary();
    }
  }

  Widget _buildBottomBar() {
    final isSummary = _step == _ReturnStep.summary;
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
          onPressed: (_canContinue && !_submitting)
              ? (isSummary ? _confirm : _goNext)
              : null,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(isSummary ? 'Confirm Return' : 'Continue'),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Step 1 - Select items
  // ---------------------------------------------------------------------

  Widget _buildSelectItems() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Select Items to Return', style: AppTheme.mainTitle),
        const SizedBox(height: 4),
        const Text(
          'Choose which items and how many units of each',
          style: AppTheme.bodySubtitle,
        ),
        const SizedBox(height: 20),
        for (final item in _returnableItems)
          _ReturnItemSelector(
            item: item,
            maxQuantity: _remainingFor(item),
            quantity: _selectedQty[item.productUuid] ?? 0,
            onChanged: (qty) =>
                setState(() => _selectedQty[item.productUuid] = qty),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Step 2 - Reason
  // ---------------------------------------------------------------------

  Widget _buildReason() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Reason for Return', style: AppTheme.mainTitle),
        const SizedBox(height: 4),
        const Text(
          'Why is the customer returning this?',
          style: AppTheme.bodySubtitle,
        ),
        const SizedBox(height: 20),
        _OptionCard(
          icon: Icons.warning_amber_rounded,
          label: 'Expired or Broken',
          selected: _reason == 'expired_broken',
          onTap: () => _selectReason('expired_broken'),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.swap_horiz,
          label: 'Wrong Item',
          selected: _reason == 'wrong_item',
          onTap: () => _selectReason('wrong_item'),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.sentiment_dissatisfied_outlined,
          label: 'Change of Mind',
          selected: _reason == 'change_of_mind',
          onTap: () => _selectReason('change_of_mind'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Step 3 - What happens to the stock (Expired/Broken only)
  // ---------------------------------------------------------------------

  Widget _buildStockAction() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('What Happens to the Product?', style: AppTheme.mainTitle),
        const SizedBox(height: 4),
        const Text(
          'The item is expired or broken - can it be resold?',
          style: AppTheme.bodySubtitle,
        ),
        const SizedBox(height: 20),
        _OptionCard(
          icon: Icons.delete_outline,
          label: 'Write Off',
          subtitle: 'Damaged - do not add back to stock',
          selected: _stockAction == 'write_off',
          onTap: () => setState(() => _stockAction = 'write_off'),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.inventory_2_outlined,
          label: 'Add Back to Stock',
          subtitle: 'Still sellable',
          selected: _stockAction == 'restock',
          onTap: () => setState(() => _stockAction = 'restock'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Step 4 - Resolution
  // ---------------------------------------------------------------------

  Widget _buildResolution() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('What Does the Customer Get?', style: AppTheme.mainTitle),
        const SizedBox(height: 4),
        Text(
          'Return value: R${_itemsValue.toStringAsFixed(2)}',
          style: AppTheme.bodySubtitle,
        ),
        const SizedBox(height: 20),
        _OptionCard(
          icon: Icons.payments_outlined,
          label: 'Refund',
          subtitle: widget.sale.paymentType == 'credit'
              ? "Settles against the customer's balance, or cash if "
                    "they don't owe anything"
              : 'Cash handed back to the customer',
          selected: _resolutionType == 'refund',
          onTap: () => _selectResolution('refund'),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.swap_horizontal_circle_outlined,
          label: 'Exchange',
          subtitle: 'Swap for a different product',
          selected: _resolutionType == 'exchange',
          onTap: () => _selectResolution('exchange'),
        ),
        const SizedBox(height: 12),
        _OptionCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Store Credit',
          subtitle: 'Value added for a future purchase',
          selected: _resolutionType == 'store_credit',
          onTap: () => _selectResolution('store_credit'),
        ),
        if (_resolutionType == 'exchange') ...[
          const SizedBox(height: 20),
          _ExchangeProductPicker(
            selected: _exchangeProduct,
            onSelected: (product) =>
                setState(() => _exchangeProduct = product),
            onClear: () => setState(() => _exchangeProduct = null),
          ),
          if (_exchangeProduct != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Replacement: R${_replacementPrice.toStringAsFixed(2)}',
                    style: AppTheme.bodySubtitle,
                  ),
                  const Spacer(),
                  Text(
                    'Returned value: R${_itemsValue.toStringAsFixed(2)}',
                    style: AppTheme.bodySubtitle,
                  ),
                ],
              ),
            ),
            if (_moneySummary != null) ...[
              const SizedBox(height: 12),
              _moneySummary!,
            ],
          ],
        ],
        if (_resolutionType == 'store_credit') ...[
          const SizedBox(height: 20),
          _CustomerPicker(
            selected: _selectedCustomer,
            onSelected: (customer) =>
                setState(() => _selectedCustomer = customer),
            onClear: () => setState(() => _selectedCustomer = null),
          ),
          if (_selectedCustomer != null && _selectedCustomer!.balance > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.syncAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.syncAmber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Store credit isn\'t available for ${_selectedCustomer!.name} '
                      'because they still owe '
                      '${formatCreditBalance(_selectedCustomer!.balance)}. '
                      'Use Refund instead.',
                      style: const TextStyle(
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
    );
  }

  // ---------------------------------------------------------------------
  // Step 5 - Summary
  // ---------------------------------------------------------------------

  Widget _buildSummary() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Review Return', style: AppTheme.mainTitle),
        const SizedBox(height: 4),
        const Text(
          'Check everything before confirming',
          style: AppTheme.bodySubtitle,
        ),
        const SizedBox(height: 20),
        _SummaryCard(
          title: 'ITEMS BEING RETURNED',
          child: Column(
            children: [
              for (final item in _chosenItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_selectedQty[item.productUuid]} × R${item.unitPrice.toStringAsFixed(2)}',
                        style: AppTheme.bodySubtitle,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'REASON',
          child: Text(
            reasonLabel(_reason!),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'STOCK IMPACT',
          child: Text(
            _stockAction == 'write_off'
                ? '${_chosenItems.fold<int>(0, (sum, i) => sum + (_selectedQty[i.productUuid] ?? 0))} unit(s) written off - not added back to stock'
                : '${_chosenItems.fold<int>(0, (sum, i) => sum + (_selectedQty[i.productUuid] ?? 0))} unit(s) added back to stock',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'RESOLUTION',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resolutionLabel(_resolutionType!),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (_resolutionType == 'exchange' && _exchangeProduct != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Exchanged for ${productDisplayName(_exchangeProduct!)}',
                  style: AppTheme.bodySubtitle,
                ),
              ],
              if (_resolutionType == 'store_credit' &&
                  _selectedCustomer != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Credited to ${_selectedCustomer!.name}',
                  style: AppTheme.bodySubtitle,
                ),
              ],
            ],
          ),
        ),
        if (_moneySummary != null) ...[
          const SizedBox(height: 12),
          _moneySummary!,
        ],
      ],
    );
  }

  /// The summary step's money card - plain-language wording covering every
  /// refund/exchange/store-credit scenario, whether the money moves as cash
  /// over the counter, against a credit customer's balance, or a mix of
  /// both when a balance can only partly cover it.
  Widget? get _moneySummary {
    final outcome = _moneyOutcome;
    final customer = _resolutionType == 'store_credit'
        ? _selectedCustomer
        : _balanceCustomer;

    if (_resolutionType == 'exchange' && _exchangeDifference == 0) {
      return const _SummaryCard(
        title: 'MONEY',
        child: Text(
          'Same price - no money changes hands.',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppTheme.syncGreen,
          ),
        ),
      );
    }

    if (customer != null && outcome.balanceDelta != 0) {
      final newBalance = customer.balance + outcome.balanceDelta;
      final String message;
      if (outcome.balanceDelta > 0) {
        message = 'R${outcome.balanceDelta.toStringAsFixed(2)} is added to '
            "${customer.name}'s balance. They now owe "
            '${formatCreditBalance(newBalance)}.';
      } else if (outcome.cashToCustomer > 0) {
        message = "${customer.name}'s balance is cleared to R0.00. They "
            'also receive R${outcome.cashToCustomer.toStringAsFixed(2)} in '
            'cash.';
      } else {
        message = 'R${(-outcome.balanceDelta).toStringAsFixed(2)} is '
            "deducted from ${customer.name}'s balance. New balance: "
            '${formatCreditBalance(newBalance)}.';
      }
      return _SummaryCard(
        title: 'CUSTOMER BALANCE',
        child: Text(
          message,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: creditBalanceColor(newBalance),
          ),
        ),
      );
    }

    if (outcome.cashFromCustomer > 0 || outcome.cashToCustomer > 0) {
      return _SummaryCard(
        title: 'MONEY',
        child: Text(
          outcome.cashFromCustomer > 0
              ? 'Customer pays R${outcome.cashFromCustomer.toStringAsFixed(2)}.'
              : 'Customer receives R${outcome.cashToCustomer.toStringAsFixed(2)} in cash.',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: outcome.cashFromCustomer > 0
                ? AppTheme.syncAmber
                : AppTheme.syncGreen,
          ),
        ),
      );
    }

    return null;
  }
}

class _ReturnAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReturnAppBar({
    required this.stepIndex,
    required this.stepCount,
    required this.onBack,
  });

  final int stepIndex;
  final int stepCount;
  final VoidCallback onBack;

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
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Process Return',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (stepIndex >= 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Step ${stepIndex + 1} of $stepCount',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

class _ReturnItemSelector extends StatelessWidget {
  const _ReturnItemSelector({
    required this.item,
    required this.maxQuantity,
    required this.quantity,
    required this.onChanged,
  });

  final SaleItem item;
  final int maxQuantity;
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'R${item.unitPrice.toStringAsFixed(2)} each · $maxQuantity available to return',
                  style: AppTheme.bodySubtitle,
                ),
              ],
            ),
          ),
          _QtyStepper(
            quantity: quantity,
            maxQuantity: maxQuantity,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.maxQuantity,
    required this.onChanged,
  });

  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: quantity > 0 ? () => onChanged(quantity - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Center(
            child: Text(
              '$quantity',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: quantity < maxQuantity ? () => onChanged(quantity + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null ? AppTheme.background : AppTheme.divider,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppTheme.textPrimary : AppTheme.syncGrey,
        ),
      ),
    );
  }
}

/// Selectable card shared by the reason, stock action, and resolution
/// steps - icon, label, optional subtitle, and a check badge when selected.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
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
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? AppTheme.primary : AppTheme.iconBorder,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppTheme.bodySubtitle),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              top: 10,
              right: 10,
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

class _ExchangeProductPicker extends ConsumerStatefulWidget {
  const _ExchangeProductPicker({
    required this.selected,
    required this.onSelected,
    required this.onClear,
  });

  final Product? selected;
  final ValueChanged<Product> onSelected;
  final VoidCallback onClear;

  @override
  ConsumerState<_ExchangeProductPicker> createState() =>
      _ExchangeProductPickerState();
}

class _ExchangeProductPickerState extends ConsumerState<_ExchangeProductPicker> {
  final _controller = TextEditingController();
  List<Product> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(productRepositoryProvider).search(query);
    if (!mounted) return;
    setState(() {
      // Only in-stock products can be picked as a replacement.
      _results = results.where((p) => p.stock > 0).toList();
      _searching = false;
    });
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _results = [];
    });
  }

  /// Matches StockScreen's own scan button exactly: opens the camera
  /// scanner and drops the result straight into the search field.
  Future<void> _openScanner() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode != null && barcode.isNotEmpty && mounted) {
      _controller.text = barcode;
      await _search(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REPLACEMENT PRODUCT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        if (selected != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: Row(
              children: [
                ProductAvatar(name: productDisplayName(selected)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    productDisplayName(selected),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  'R${selected.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _controller.clear();
                      _results = [];
                    });
                    widget.onClear();
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _controller,
            onChanged: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.iconBorder),
                      onPressed: _clearSearch,
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
                    onPressed: _openScanner,
                  ),
                ],
              ),
              hintText: 'Search for the replacement product...',
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 240),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _results.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppTheme.divider),
                itemBuilder: (context, index) {
                  final product = _results[index];
                  return ListTile(
                    leading: ProductAvatar(
                      name: productDisplayName(product),
                      size: 36,
                    ),
                    title: Text(productDisplayName(product)),
                    subtitle: Text('${product.stock} in stock'),
                    trailing: Text(
                      'R${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    onTap: () => widget.onSelected(product),
                  );
                },
              ),
            )
          else if (_controller.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 20,
                        color: AppTheme.iconBorder,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No in-stock products match - edit your search or '
                          'clear it and try again',
                          style: AppTheme.bodySubtitle,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _clearSearch,
                    child: const Text('Clear Search'),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _CustomerPicker extends ConsumerStatefulWidget {
  const _CustomerPicker({
    required this.selected,
    required this.onSelected,
    required this.onClear,
  });

  final CreditCustomer? selected;
  final ValueChanged<CreditCustomer> onSelected;
  final VoidCallback onClear;

  @override
  ConsumerState<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<_CustomerPicker> {
  final _controller = TextEditingController();
  List<CreditCustomer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customers = await ref.read(creditRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<CreditCustomer> get _filtered {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) return _customers.take(5).toList();
    return _customers
        .where((c) => c.name.toLowerCase().contains(query))
        .toList();
  }

  /// Same inline bottom sheet Checkout's credit-payment flow uses to add a
  /// customer on the spot - name required, phone optional. Saves it, then
  /// selects it as this return's store-credit recipient.
  Future<void> _addNewCustomer() async {
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
      setState(() => _customers = [customer, ..._customers]);
      widget.onSelected(customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CREDIT CUSTOMER',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (selected != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: Row(
              children: [
                ProductAvatar(name: selected.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selected.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _controller.clear());
                    widget.onClear();
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
          )
        else ...[
          if (_customers.isNotEmpty) ...[
            TextField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search customer...',
              ),
            ),
            const SizedBox(height: 8),
            for (final customer in _filtered)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ProductAvatar(name: customer.name, size: 36),
                title: Text(customer.name),
                subtitle: Text(
                  'Balance: ${formatCreditBalance(customer.balance)}',
                ),
                onTap: () => widget.onSelected(customer),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 20,
                    color: AppTheme.iconBorder,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No credit customers yet - add one below to give '
                      'them store credit',
                      style: AppTheme.bodySubtitle,
                    ),
                  ),
                ],
              ),
            ),
          InkWell(
            onTap: _addNewCustomer,
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
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
