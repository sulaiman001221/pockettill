import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Sales screen - static placeholder UI matching the empty-cart design.
/// No real data, providers, or cart logic wired up yet; used only as the
/// [ShellScreen]'s body, not a routed screen of its own.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'search');

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tapping anywhere outside the search field dismisses its focus -
      // without this, once focused it never lets go, even on an outside tap.
      onTap: () =>
          _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const _ScanProductCard(),
          _SearchBar(focusNode: _searchFocusNode),
          const Expanded(child: _EmptyCart()),
          const _CheckoutBar(),
        ],
      ),
    );
  }
}

class _ScanProductCard extends StatelessWidget {
  const _ScanProductCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 20, right: 20, top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner, size: 32, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Scan Product',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.focusNode});

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 12),
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: TextField(
        focusNode: focusNode,
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.search,
            color: AppTheme.searchPlaceholder,
          ),
          hintText: 'Search or enter product name',
          hintStyle: AppTheme.searchPlaceholderStyle,
          // Override every border state, not just the default `border` -
          // otherwise the themed blue focusedBorder shows through whenever
          // this field has focus, which clashes with the borderless design.
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: AppTheme.iconBorder,
          ),
          const SizedBox(height: 16),
          Text('No items added yet', style: AppTheme.mainTitle),
          const SizedBox(height: 8),
          Text('Scan or search products to start a sale', style: AppTheme.bodySubtitle),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar();

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
      padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Total:', style: AppTheme.totalLabel),
              const Spacer(),
              Text('R0.00', style: AppTheme.totalValue),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              // Disabled - the cart is empty.
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.checkoutButtonBackground,
                disabledBackgroundColor: AppTheme.checkoutButtonBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.credit_card, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Checkout', style: AppTheme.buttonText),
                  Spacer(),
                  Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
