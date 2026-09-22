import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/realtime_data_sync_service.dart';
import '../../core/sync/sync_service.dart';
import '../../shared/models/product.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../../shared/widgets/scroll_to_top_button.dart';
import 'add_product_screen.dart';
import 'barcode_scanner_screen.dart';
import 'catalogue_browse_screen.dart';
import 'risk_log_providers.dart';
import 'risk_log_screen.dart';
import 'stock_ui.dart';

enum _StockFilter { all, normal, lowStock, outOfStock }

enum _AddProductChoice { browseCatalogue, addManually }

/// Stock screen: search/scan, filter chips, and the scrollable product
/// list. All reads/writes go through [productRepositoryProvider] - never
/// directly to Isar.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'search');
  final ScrollController _scrollController = ScrollController();

  List<Product> _products = [];
  bool _loading = true;
  _StockFilter _filter = _StockFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _syncImagesEagerly();
  }

  /// Proactively checks for newer catalogue/enhanced images and re-caches
  /// anything missing as soon as Stock opens, rather than waiting for the
  /// next periodic background sync (up to ~30s away, per
  /// ReachabilityService's ping interval) - the whole point of opening
  /// Stock right after an admin enhances a photo is to see it promptly, not
  /// on whatever schedule the next unrelated sync happens to land on
  /// (found slow to update 2026-09-08). Silent refresh - doesn't toggle the
  /// loading spinner, since the products themselves are usually already
  /// loaded and only their images might change.
  Future<void> _syncImagesEagerly() async {
    await ref.read(imageSyncServiceProvider).syncStoreImages();
    if (!mounted) return;
    final products = await ref.read(productRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() => _products = products);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final products = await ref.read(productRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  bool _matchesFilter(Product product, _StockFilter filter) {
    switch (filter) {
      case _StockFilter.all:
        return true;
      case _StockFilter.normal:
        return stockStatusOf(product) == ProductStockStatus.normal;
      case _StockFilter.lowStock:
        return stockStatusOf(product) == ProductStockStatus.lowStock;
      case _StockFilter.outOfStock:
        return stockStatusOf(product) == ProductStockStatus.outOfStock;
    }
  }

  int _countFor(_StockFilter filter) =>
      _products.where((p) => _matchesFilter(p, filter)).length;

  List<Product> get _filteredProducts {
    var list = _products.where((p) => _matchesFilter(p, _filter));
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where(
        (p) =>
            productDisplayName(p).toLowerCase().contains(query) ||
            p.barcode.toLowerCase().contains(query),
      );
    }
    return list.toList();
  }

  Future<void> _openScanner() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode != null && barcode.isNotEmpty && mounted) {
      setState(() {
        _searchController.text = barcode;
        _searchQuery = barcode;
      });
    }
  }

  Future<void> _openAddProduct({Product? existing}) async {
    // The deleted Product from AddProductScreen's delete flow, 'updated' from
    // its edit-mode save, or null if the user just backed out without saving.
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => AddProductScreen(existingProduct: existing),
      ),
    );
    await _loadProducts();
    if (!mounted || result == null) return;

    if (result is Product) {
      _handleProductDeleted(result);
    } else if (result == 'updated') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product updated')));
    }
  }

  /// Replaces the earlier expand-in-place FAB animation (dropped per user
  /// feedback, 2026-09-05) with a plain modal bottom sheet - same pattern
  /// [_quickAddStock] already uses for [_AddStockSheet], so "tap the FAB,
  /// choose from a sheet" is one consistent idiom across this screen
  /// instead of two different interaction styles.
  Future<void> _openAddProductMenu() async {
    final choice = await showModalBottomSheet<_AddProductChoice>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add Product', style: AppTheme.mainTitle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                // Same blue ElevatedButton.icon style as History's "End of
                // Day Summary" button (2026-09-09 per feedback).
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_AddProductChoice.browseCatalogue),
                  icon: const Icon(Icons.search),
                  label: const Text('Browse Catalogue'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_AddProductChoice.addManually),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Add Manually'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null) return;
    switch (choice) {
      case _AddProductChoice.browseCatalogue:
        await _openCatalogueBrowse();
      case _AddProductChoice.addManually:
        await _openAddProduct();
    }
  }

  Future<void> _openCatalogueBrowse() async {
    // An int (how many products were imported) once the browse ->
    // price-setting flow finishes, or null if the user just backed out.
    final imported = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const CatalogueBrowseScreen()),
    );
    await _loadProducts();
    if (!mounted || imported == null || imported <= 0) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$imported product${imported == 1 ? '' : 's'} added to your store',
        ),
      ),
    );
  }

  /// Deletes [product] immediately (removing it from the list and Isar) and
  /// shows an Undo snackbar. Undo recreates it via [ProductRepository.save];
  /// if the snackbar closes without Undo, nothing more is needed - the
  /// delete already happened.
  Future<void> _handleProductDeleted(Product product) async {
    final repo = ref.read(productRepositoryProvider);

    setState(() {
      _products = _products.where((p) => p.uuid != product.uuid).toList();
    });
    await repo.delete(product.uuid);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        content: const Text('Product deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repo.save(product);
            if (mounted) await _loadProducts();
          },
        ),
      ),
    );

    // A snackbar with an action never auto-dismisses while an accessibility
    // service is running (Flutter ignores `duration` then, to keep the
    // action reachable) - so close it manually.
    var closed = false;
    snackBar.closed.whenComplete(() => closed = true);
    Timer(const Duration(seconds: 4), () {
      if (!closed) snackBar.close();
    });
  }

  Future<void> _quickAddStock(Product product) async {
    final quantity = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddStockSheet(product: product),
    );
    if (quantity != null && quantity != 0) {
      await ref.read(productRepositoryProvider).adjustStock(
        product.uuid,
        quantity,
      );
      // Named "Add Stock" and only offers a number keypad, but nothing
      // stops someone typing a negative quantity - that's a manual
      // reduction just as much as editing the stock field directly on the
      // product form (see ProductRepository.save's own risk-log hook).
      if (quantity < 0) {
        await ref.read(riskLogRepositoryProvider).record(
          type: 'manual_stock_reduction',
          description: 'Stock manually reduced for ${product.name}',
          beforeValue: '${product.stock}',
          afterValue: '${product.stock + quantity}',
          entityName: product.name,
        );
      }
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    // A product changed anywhere - created, edited, sold or restocked on
    // another device (stock is part of the product row), or deleted - reload
    // so this screen reflects it without the owner having to pull to
    // refresh. Silent - the underlying Product read is local/instant, no
    // loading spinner needed for it. See RealtimeDataSyncService.
    ref.listen(productsChangedProvider, (_, _) => _loadProducts());

    return GestureDetector(
      // Tapping anywhere outside the search field dismisses its focus -
      // without this, once focused it never lets go, even on an outside tap.
      onTap: () =>
          _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: CustomAppBar(
          showMenuIcon: false,
          title: 'Stock',
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textPrimary),
            onSelected: (value) {
              if (value == 'risk_log') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const RiskLogScreen(category: RiskLogCategory.stock),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'risk_log',
                child: ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Risk Log'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddProductMenu,
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add Product',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: Stack(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(child: _buildSearchBar()),
                        SliverToBoxAdapter(child: _buildFilterChips()),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        const SliverToBoxAdapter(child: _SectionLabel('PRODUCTS')),
                        if (_products.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'No products yet',
                              subtitle: 'Tap Add Product to get started',
                            ),
                          )
                        else if (filtered.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              icon: Icons.search_off,
                              title: 'No matching products',
                              subtitle: 'Try a different search or filter',
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product = filtered[index];
                                return _ProductListItem(
                                  product: product,
                                  onQuickAdd: () => _quickAddStock(product),
                                  onEdit: () => _openAddProduct(existing: product),
                                );
                              },
                              childCount: filtered.length,
                            ),
                          ),
                        // Enough clearance that the last card's edit/quick-add
                        // buttons never sit under the scroll-to-top button or
                        // the main Add Product FAB once scrolled all the way
                        // down - 96 wasn't quite enough (2026-09-06).
                        const SliverToBoxAdapter(child: SizedBox(height: 140)),
                      ],
                    ),
                  ),
            ScrollToTopButton(controller: _scrollController, bottom: 108),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Container(
        height: 52,
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
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.searchPlaceholder,
            ),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.qr_code_scanner,
                color: AppTheme.primary,
              ),
              onPressed: _openScanner,
            ),
            hintText: 'Search product...',
            hintStyle: AppTheme.searchPlaceholderStyle,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _FilterChipButton(
            label: 'All',
            count: _countFor(_StockFilter.all),
            isActive: _filter == _StockFilter.all,
            onTap: () => setState(() => _filter = _StockFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Normal',
            count: _countFor(_StockFilter.normal),
            isActive: _filter == _StockFilter.normal,
            onTap: () => setState(() => _filter = _StockFilter.normal),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Low Stock',
            count: _countFor(_StockFilter.lowStock),
            isActive: _filter == _StockFilter.lowStock,
            onTap: () => setState(() => _filter = _StockFilter.lowStock),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Out',
            count: _countFor(_StockFilter.outOfStock),
            isActive: _filter == _StockFilter.outOfStock,
            onTap: () => setState(() => _filter = _StockFilter.outOfStock),
          ),
        ],
      ),
    );
  }

}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(9999),
            border: isActive
                ? null
                : Border.all(color: AppTheme.divider),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              color: isActive ? Colors.white : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma-specified row (2026-09-05): a big product photo, name, stock
/// count (color-coded instead of the old status pill), and price - no card
/// background/shadow, just [ProductRow]'s own divider between rows.
class _ProductListItem extends StatelessWidget {
  const _ProductListItem({
    required this.product,
    required this.onQuickAdd,
    required this.onEdit,
  });

  final Product product;
  final VoidCallback onQuickAdd;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final status = stockStatusOf(product);

    return ProductRow(
      name: productDisplayName(product),
      imageUrl: product.imageUrl,
      cacheKey: product.barcode,
      cachedImagePath: product.cachedImagePath,
      subtitle: status == ProductStockStatus.outOfStock
          ? const _OutOfStockTag()
          : Text(
              '${product.stock} in stock',
              style: TextStyle(color: stockStatusColor(status), fontSize: 13),
            ),
      bottomLeft: Text(
        'R${product.price.toStringAsFixed(2)}',
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RowSquareButton(
            icon: Icons.edit_outlined,
            onTap: onEdit,
            background: AppTheme.surface,
            iconColor: AppTheme.iconBorder,
            border: AppTheme.divider,
          ),
          const SizedBox(width: 8),
          RowSquareButton(
            icon: Icons.add,
            onTap: onQuickAdd,
            background: AppTheme.primary,
            iconColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Brought back 2026-09-06, out-of-stock only - "like it was before" (the
/// old 3-state StockStatusBadge, dropped 2026-09-05 in favor of plain
/// color-coded "X in stock" text). Normal/low stock still use the plain
/// text - only the zero-stock case is urgent enough to warrant a tag.
class _OutOfStockTag extends StatelessWidget {
  const _OutOfStockTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.logoutRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Text(
        'Out of Stock',
        style: TextStyle(
          color: AppTheme.logoutRed,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppTheme.iconBorder),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.mainTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTheme.bodySubtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddStockSheet extends StatefulWidget {
  const _AddStockSheet({required this.product});

  final Product product;

  @override
  State<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends State<_AddStockSheet> {
  final TextEditingController _controller = TextEditingController(text: '1');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final quantity = int.tryParse(_controller.text.trim());
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Stock', style: AppTheme.mainTitle),
          const SizedBox(height: 4),
          Text(widget.product.name, style: AppTheme.bodySubtitle),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Quantity to add'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              child: const Text('Confirm'),
            ),
          ),
        ],
      ),
    );
  }
}
