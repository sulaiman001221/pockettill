import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hardware/camera_scanner_service.dart';
import '../../main.dart';
import '../../shared/models/product.dart';
import '../../shared/theme/app_theme.dart';
import '../stock/add_product_screen.dart';
import '../stock/barcode_scanner_screen.dart';
import '../stock/stock_ui.dart';
import 'cart_item.dart';
import 'checkout_screen.dart';
import 'sales_providers.dart';

/// Sales screen - the core POS screen. Owns the scan button, search bar,
/// cart, and checkout hand-off; used only as the [ShellScreen]'s body, not a
/// routed screen of its own.
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'search');
  final TextEditingController _searchController = TextEditingController();
  final LayerLink _searchBarLink = LayerLink();
  StreamSubscription<String>? _scanSubscription;
  bool _showingNotFoundSheet = false;

  @override
  void initState() {
    super.initState();
    _listenForHardwareScans();
  }

  /// Hardware (Sunmi) scanners emit continuously once bound, independent of
  /// any screen being open - so this screen listens for the app's whole
  /// lifetime rather than only while some scanner UI is on screen.
  ///
  /// Camera devices are deliberately excluded: opening [BarcodeScannerScreen]
  /// mounts a `MobileScanner` widget that starts emitting on this exact same
  /// stream, and [_onScanProductTap] already awaits that screen's result
  /// directly - listening here too would handle every camera scan twice.
  Future<void> _listenForHardwareScans() async {
    await ref.read(scannerInitProvider.future);
    if (!mounted) return;
    final scanner = ref.read(scannerServiceProvider);
    if (scanner is CameraScannerService) return;
    _scanSubscription = scanner.onBarcodeScanned.listen(_handleBarcode);
  }

  Future<void> _onScanProductTap() async {
    final scanner = ref.read(scannerServiceProvider);
    if (scanner is CameraScannerService) {
      final barcode = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
      );
      if (barcode != null && barcode.isNotEmpty) {
        _handleBarcode(barcode);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Press the scanner button on your device to scan.'),
      ),
    );
  }

  Future<void> _handleBarcode(String barcode) async {
    final product = await ref
        .read(salesNotifierProvider.notifier)
        .onBarcodeScanned(barcode);
    if (!mounted) return;

    // A found product just shows up in the cart directly - no separate
    // confirmation popup needed on top of that.
    if (product == null) {
      _showProductNotFoundSheet(barcode);
    }
  }

  void _showProductNotFoundSheet(String barcode) {
    if (_showingNotFoundSheet) return;
    _showingNotFoundSheet = true;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _ProductNotFoundSheet(
        barcode: barcode,
        onAddToStock: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddProductScreen(initialBarcode: barcode),
            ),
          );
        },
        onCancel: () => Navigator.of(sheetContext).pop(),
      ),
    ).whenComplete(() => _showingNotFoundSheet = false);
  }

  void _onSearchChanged(String query) {
    ref.read(salesNotifierProvider.notifier).searchProducts(query);
  }

  void _onSelectSearchResult(Product product) {
    ref.read(salesNotifierProvider.notifier).addToCart(product);
    _searchController.clear();
    _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope);
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesNotifierProvider);

    return GestureDetector(
      // Tapping anywhere outside the search field dismisses its focus -
      // without this, once focused it never lets go, even on an outside tap.
      onTap: () =>
          _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Column(
            children: [
              _ScanProductCard(onTap: _onScanProductTap),
              CompositedTransformTarget(
                link: _searchBarLink,
                child: _SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                ),
              ),
              // A fixed gap, not the cart list's own (scrollable) padding -
              // otherwise it scrolls away and the first cart card ends up
              // flush against the search bar, and both are white.
              const SizedBox(height: 12),
              Expanded(
                child: state.cartItems.isEmpty
                    ? const _EmptyCart()
                    : _CartList(items: state.cartItems),
              ),
              _CheckoutBar(cartItems: state.cartItems, total: state.cartTotal),
            ],
          ),
          if (state.searchQuery.isNotEmpty)
            CompositedTransformFollower(
              link: _searchBarLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 68),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width - 40,
                  child: _SearchResultsList(
                    results: state.searchResults,
                    isSearching: state.isSearching,
                    onSelect: _onSelectSearchResult,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanProductCard extends StatelessWidget {
  const _ScanProductCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 12),
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        // Stronger than a typical resting-card shadow - the cart list below
        // is also white, so this is what actually separates the search bar
        // from it once cart cards are scrolled up underneath.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
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

class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.isSearching,
    required this.onSelect,
  });

  final List<Product> results;
  final bool isSearching;
  final ValueChanged<Product> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isSearching
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : results.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No products found', style: AppTheme.bodySubtitle),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: results.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppTheme.divider),
                itemBuilder: (context, index) {
                  final product = results[index];
                  final outOfStock = product.stock <= 0;
                  return ListTile(
                    enabled: !outOfStock,
                    leading: ProductAvatar(
                      name: productDisplayName(product),
                      size: 36,
                    ),
                    title: Text(productDisplayName(product)),
                    subtitle: Text(
                      outOfStock ? 'Out of stock' : '${product.stock} in stock',
                      style: TextStyle(
                        color: outOfStock
                            ? AppTheme.logoutRed
                            : AppTheme.textSecondary,
                      ),
                    ),
                    trailing: Text(
                      'R${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    onTap: outOfStock ? null : () => onSelect(product),
                  );
                },
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
          Text(
            'Scan or search products to start a sale',
            style: AppTheme.bodySubtitle,
          ),
        ],
      ),
    );
  }
}

class _CartList extends ConsumerWidget {
  const _CartList({required this.items});

  final List<CartItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(salesNotifierProvider.notifier);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.product.uuid),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: AppTheme.logoutRed,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) {
            notifier.removeFromCart(item.product.uuid);
            // Clear any snackbar already showing first - otherwise removing
            // several items in quick succession queues one snackbar after
            // another, and it can look like a single one is stuck on screen
            // for a very long time.
            final messenger = ScaffoldMessenger.of(context)
              ..clearSnackBars();
            final snackBar = messenger.showSnackBar(
              SnackBar(
                content: Text('${productDisplayName(item.product)} removed'),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => notifier.restoreCartItem(item, index),
                ),
              ),
            );
            // A snackbar with an action never auto-dismisses while an
            // accessibility service is running (Flutter ignores `duration`
            // then, to keep the action reachable) - so close it manually.
            // The closed-check makes the timer a no-op if the user already
            // tapped Undo or a newer removal cleared this snackbar.
            var closed = false;
            snackBar.closed.whenComplete(() => closed = true);
            Timer(const Duration(seconds: 4), () {
              if (!closed) snackBar.close();
            });
          },
          child: _CartItemTile(item: item),
        );
      },
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(salesNotifierProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          ProductAvatar(name: productDisplayName(item.product)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productDisplayName(item.product),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'R${item.product.price.toStringAsFixed(2)} each',
                  style: AppTheme.bodySubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => notifier.decrementQuantity(item.product.uuid),
                  ),
                  SizedBox(
                    width: 28,
                    child: Center(
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => notifier.incrementQuantity(item.product.uuid),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'R${item.subtotal.toStringAsFixed(2)}',
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

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppTheme.textPrimary),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cartItems, required this.total});

  final List<CartItem> cartItems;
  final double total;

  @override
  Widget build(BuildContext context) {
    final hasItems = cartItems.isNotEmpty;
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
              Text('R${total.toStringAsFixed(2)}', style: AppTheme.totalValue),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: hasItems
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          cartItems: cartItems,
                          cartTotal: total,
                        ),
                      ),
                    )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasItems
                    ? AppTheme.primary
                    : AppTheme.checkoutButtonBackground,
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

class _ProductNotFoundSheet extends StatelessWidget {
  const _ProductNotFoundSheet({
    required this.barcode,
    required this.onAddToStock,
    required this.onCancel,
  });

  final String barcode;
  final VoidCallback onAddToStock;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppTheme.iconBorder),
            const SizedBox(height: 12),
            const Text('Product Not Found', style: AppTheme.mainTitle),
            const SizedBox(height: 8),
            Text(
              'No product matches barcode $barcode.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySubtitle,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onAddToStock,
                child: const Text('Add to Stock'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
