import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/product.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import 'add_product_screen.dart';
import 'barcode_scanner_screen.dart';
import 'stock_ui.dart';

enum _StockFilter { all, normal, lowStock, outOfStock }

/// Stock screen: search/scan, filter chips, summary cards, and the
/// scrollable product list. All reads/writes go through
/// [productRepositoryProvider] - never directly to Isar.
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'search');

  List<Product> _products = [];
  bool _loading = true;
  _StockFilter _filter = _StockFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return GestureDetector(
      // Tapping anywhere outside the search field dismisses its focus -
      // without this, once focused it never lets go, even on an outside tap.
      onTap: () =>
          _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: const CustomAppBar(showMenuIcon: false, title: 'Stock'),
        backgroundColor: AppTheme.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddProduct(),
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add Product',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProducts,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildSearchBar()),
                    SliverToBoxAdapter(child: _buildFilterChips()),
                    SliverToBoxAdapter(child: _buildSummaryCards()),
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
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
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

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Total Products',
              value: '${_products.length}',
              color: AppTheme.textPrimary,
              background: AppTheme.surface,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'Low Stock',
              value: '${_countFor(_StockFilter.lowStock)}',
              color: AppTheme.syncAmber,
              background: AppTheme.surface,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'Out of Stock',
              value: '${_countFor(_StockFilter.outOfStock)}',
              color: AppTheme.logoutRed,
              background: AppTheme.surface,
            ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

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

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductAvatar(name: product.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        productDisplayName(product),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StockStatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'R${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${product.stock} in stock',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: onQuickAdd,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    color: AppTheme.iconBorder,
                    size: 20,
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
