import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/catalogue_browse_repository.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../../shared/widgets/scroll_to_top_button.dart';
import 'add_product_screen.dart';
import 'barcode_scanner_screen.dart';
import 'catalogue_price_setting_screen.dart';
import 'stock_ui.dart';

const _kAllCategory = 'All';

/// Browse PocketTill's shared, cross-store product catalogue and import
/// products straight into this store's stock (quantity 0, price set on the
/// next screen or later). Reads only - never writes to `catalogue_products`
/// itself, which is admin-write-only (see SCHEMA_TRUTH.md).
///
/// Pops with an `int` (how many products were actually imported) once the
/// price-setting flow finishes, so the caller (Stock screen) can show a
/// success message - or `null`/nothing if the user just backed out.
class CatalogueBrowseScreen extends ConsumerStatefulWidget {
  const CatalogueBrowseScreen({super.key});

  @override
  ConsumerState<CatalogueBrowseScreen> createState() =>
      _CatalogueBrowseScreenState();
}

class _CatalogueBrowseScreenState extends ConsumerState<CatalogueBrowseScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<CategoryCount> _categories = [];

  String _selectedCategory = _kAllCategory;
  List<CatalogueBrowseItem> _products = [];
  bool _loadingProducts = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;

  // Non-null while a text search or barcode scan match is active - takes
  // over the body in place of the category/product browse view.
  List<CatalogueBrowseItem>? _searchResults;
  bool _searching = false;

  Set<String> _ownedBarcodes = {};
  final Map<String, CatalogueBrowseItem> _selectedItems = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _loadOwnedBarcodes();
    _loadCategories();
    _loadCategoryProducts(_kAllCategory);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnedBarcodes() async {
    final products = await ref.read(productRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() => _ownedBarcodes = products.map((p) => p.barcode).toSet());
  }

  Future<void> _loadCategories() async {
    final repo = ref.read(catalogueBrowseRepositoryProvider);
    // Cache-first (see _loadCategoryProducts's doc comment) - the chip
    // labels themselves shouldn't wait on the network any more than the
    // products underneath them do.
    final cached = await repo.getCachedCategories();
    if (mounted && cached.isNotEmpty) setState(() => _categories = cached);

    final categories = await repo.fetchCategories();
    if (!mounted) return;
    setState(() => _categories = categories);
  }

  Future<void> _loadCategoryProducts(String category) async {
    setState(() {
      _selectedCategory = category;
      _offset = 0;
      _hasMore = true;
    });
    final repo = ref.read(catalogueBrowseRepositoryProvider);

    // Cache-first, then a silent network refresh: every category-chip tap
    // used to block on a fresh network round-trip even when the exact same
    // page had already been fetched (and cached) moments earlier - felt
    // like the screen had hung whenever the connection was at all slow.
    // Showing what's already known instantly, then quietly replacing it
    // once the refresh resolves, is the same "stale-while-revalidate"
    // pattern the rest of the app already uses for cross-device Realtime
    // updates - this is just the single-device, same-session version of
    // it. Found 2026-09-14.
    final cached = category == _kAllCategory
        ? await repo.getCachedAll()
        : await repo.getCachedByCategory(category);
    if (!mounted || _selectedCategory != category) return;
    final hasCached = cached.isNotEmpty;
    setState(() {
      _products = cached;
      _offset = cached.length;
      _loadingProducts = !hasCached;
    });

    final items = category == _kAllCategory
        ? await repo.fetchAll(offset: 0)
        : await repo.fetchByCategory(category, offset: 0);
    if (!mounted || _selectedCategory != category) return;
    setState(() {
      _products = items;
      _offset = items.length;
      _hasMore = items.length == CatalogueBrowseRepository.pageSize;
      _loadingProducts = false;
    });
  }

  void _onScroll() {
    if (_searchResults != null) return;
    if (!_hasMore || _loadingMore || _loadingProducts) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _loadMore() async {
    final category = _selectedCategory;
    setState(() => _loadingMore = true);
    final repo = ref.read(catalogueBrowseRepositoryProvider);
    final items = category == _kAllCategory
        ? await repo.fetchAll(offset: _offset)
        : await repo.fetchByCategory(category, offset: _offset);
    if (!mounted || _selectedCategory != category) return;
    setState(() {
      _products = [..._products, ...items];
      _offset += items.length;
      _hasMore = items.length == CatalogueBrowseRepository.pageSize;
      _loadingMore = false;
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await ref
        .read(catalogueBrowseRepositoryProvider)
        .search(query);
    // The search field may have moved on to a different query (or been
    // cleared) while this was in flight - a stale response must never
    // overwrite what's now showing.
    if (!mounted || _searchController.text.trim() != query) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    final item = await ref
        .read(catalogueBrowseRepositoryProvider)
        .findByBarcode(code);
    if (!mounted) return;

    if (item != null) {
      _searchController.text = item.name;
      setState(() => _searchResults = [item]);
      return;
    }

    // Not in the catalogue - fall back to the normal manual-add flow,
    // pre-filled with the scanned barcode.
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(builder: (_) => AddProductScreen(initialBarcode: code)),
    );
    if (!mounted || result == null) return;
    await _loadOwnedBarcodes();
  }

  void _toggleSelection(CatalogueBrowseItem item) {
    setState(() {
      if (_selectedItems.containsKey(item.barcode)) {
        _selectedItems.remove(item.barcode);
      } else {
        _selectedItems[item.barcode] = item;
      }
    });
  }

  /// Nothing is created here - the price-setting screen is what actually
  /// calls [ProductRepository.importFromCatalogue], only once the user
  /// confirms via one of its two buttons. Backing out of that screen (or
  /// this one) commits nothing.
  Future<void> _importSelected() async {
    final items = _selectedItems.values.toList();
    final imported = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => CataloguePriceSettingScreen(items: items),
      ),
    );
    if (!mounted || imported == null) return;

    setState(() => _selectedItems.clear());
    await _loadOwnedBarcodes();
    Navigator.of(context).pop(imported);
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchResults != null;

    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'PocketTill Catalogue'),
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              _buildSearchBar(),
              if (!isSearching) ...[
                _buildCategoryChips(),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: isSearching ? _buildSearchResults() : _buildProductArea(),
              ),
            ],
          ),
          ScrollToTopButton(
            controller: _scrollController,
            bottom: _selectedItems.isEmpty ? 96 : 84,
          ),
        ],
      ),
      bottomNavigationBar: _selectedItems.isEmpty ? null : _buildImportBar(),
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
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: AppTheme.searchPlaceholder),
            hintText: 'Search catalogue by name or barcode...',
            hintStyle: AppTheme.searchPlaceholderStyle,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: AppTheme.textSecondary),
              onPressed: _scanBarcode,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _CategoryChip(
            label: _kAllCategory,
            isActive: _selectedCategory == _kAllCategory,
            onTap: () => _loadCategoryProducts(_kAllCategory),
          ),
          for (final category in _categories) ...[
            const SizedBox(width: 8),
            _CategoryChip(
              label: category.category,
              count: category.count,
              isActive: _selectedCategory == category.category,
              onTap: () => _loadCategoryProducts(category.category),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductArea() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_products.isEmpty) {
      return const Center(
        child: Text('No products in this category', style: AppTheme.bodySubtitle),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadCategoryProducts(_selectedCategory),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _products.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) return _buildLoadMoreSpinner();
          return _buildRow(_products[index]);
        },
      ),
    );
  }

  Widget _buildLoadMoreSpinner() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    final results = _searchResults!;
    if (results.isEmpty) {
      return const Center(
        child: Text('No matching products', style: AppTheme.bodySubtitle),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: results.length,
      itemBuilder: (context, index) => _buildRow(results[index]),
    );
  }

  Widget _buildRow(CatalogueBrowseItem item) {
    final alreadyOwned = _ownedBarcodes.contains(item.barcode);
    final selected = _selectedItems.containsKey(item.barcode);
    return _CatalogueProductRow(
      item: item,
      alreadyOwned: alreadyOwned,
      selected: selected,
      onTap: alreadyOwned ? null : () => _toggleSelection(item),
    );
  }


  Widget _buildImportBar() {
    final count = _selectedItems.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _importSelected,
            child: Text('Add $count product${count == 1 ? '' : 's'} to my store'),
          ),
        ),
      ),
    );
  }
}

/// Same visual language as Stock's own filter chips (_FilterChipButton) -
/// deliberately, per design direction to make the two screens read as one
/// family rather than each inventing its own chip style.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = count == null ? label : '$label ($count)';
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
            border: isActive ? null : Border.all(color: AppTheme.divider),
          ),
          child: Text(
            text,
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

/// Same [ProductRow] shell Stock uses (Figma spec, 2026-09-05) - mass and
/// category under the name instead of stock count and price, and a
/// checkbox (or an "In Stock" pill once already owned) instead of the
/// edit/quick-add buttons, since importing is a selection action here, not
/// a stock edit.
class _CatalogueProductRow extends StatelessWidget {
  const _CatalogueProductRow({
    required this.item,
    required this.alreadyOwned,
    required this.selected,
    required this.onTap,
  });

  final CatalogueBrowseItem item;
  final bool alreadyOwned;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if ((item.mass ?? '').isNotEmpty) item.mass!,
      if ((item.category ?? '').isNotEmpty) item.category!,
    ];

    return ProductRow(
      name: item.name,
      imageUrl: item.imageUrl,
      cacheKey: item.barcode,
      // Not dimmed for already-owned items (removed 2026-09-08 per
      // feedback) - the "In Stock" pill on the trailing edge is signal
      // enough on its own; fading the whole row read as the item being
      // unavailable/disabled, which it isn't.
      onTap: onTap,
      subtitle: subtitleParts.isEmpty
          ? null
          : Text(subtitleParts.join(' · '), style: AppTheme.bodySubtitle),
      bottomLeft: const SizedBox.shrink(),
      trailing: alreadyOwned
          ? const _InStockPill()
          : Checkbox(
              value: selected,
              onChanged: (_) => onTap?.call(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}

class _InStockPill extends StatelessWidget {
  const _InStockPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.divider,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Text(
        'In Stock',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
