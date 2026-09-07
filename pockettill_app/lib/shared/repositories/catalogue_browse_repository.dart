import 'package:isar/isar.dart';

import '../../core/supabase/supabase_service.dart';
import '../models/cached_catalogue_product.dart';

const _uncategorised = 'Uncategorised';

/// One row from `catalogue_products` (or its local cache), as shown on the
/// Catalogue Browse screen.
class CatalogueBrowseItem {
  const CatalogueBrowseItem({
    required this.barcode,
    required this.name,
    this.mass,
    this.category,
    this.imageUrl,
  });

  final String barcode;
  final String name;
  final String? mass;
  final String? category;
  final String? imageUrl;

  factory CatalogueBrowseItem.fromRow(Map<String, dynamic> row) =>
      CatalogueBrowseItem(
        barcode: row['barcode'] as String,
        name: row['name'] as String,
        mass: row['mass'] as String?,
        category: row['category'] as String?,
        imageUrl: row['image_url'] as String?,
      );

  factory CatalogueBrowseItem.fromCached(CachedCatalogueProduct cached) =>
      CatalogueBrowseItem(
        barcode: cached.barcode,
        name: cached.name,
        mass: cached.mass,
        category: cached.category,
        imageUrl: cached.imageUrl,
      );
}

class CategoryCount {
  const CategoryCount({required this.category, required this.count});
  final String category;
  final int count;
}

/// Reads from the shared, cross-store `catalogue_products` table (browsable
/// by every store, not owned by any one of them - see SCHEMA_TRUTH.md), with
/// a local Isar cache so Catalogue Browse keeps working offline once a
/// category or search has been fetched at least once. Never writes to
/// `catalogue_products` itself - that table is admin-write-only.
class CatalogueBrowseRepository {
  CatalogueBrowseRepository({required Isar isar}) : _isar = isar;

  final Isar _isar;

  static const pageSize = 20;

  /// Category names with product counts, e.g. "Beverages (124)". Falls back
  /// to counting whatever's cached locally when offline.
  Future<List<CategoryCount>> fetchCategories() async {
    try {
      final rows = await SupabaseService.supabaseClient.rpc(
        'catalogue_category_counts',
      );
      return (rows as List)
          .map(
            (r) => CategoryCount(
              category: r['category'] as String,
              count: (r['product_count'] as num).toInt(),
            ),
          )
          .toList();
    } catch (_) {
      final cached = await _isar.cachedCatalogueProducts.where().findAll();
      final counts = <String, int>{};
      for (final item in cached) {
        final category = item.category ?? _uncategorised;
        counts[category] = (counts[category] ?? 0) + 1;
      }
      final result = counts.entries
          .map((e) => CategoryCount(category: e.key, count: e.value))
          .toList()
        ..sort((a, b) => a.category.compareTo(b.category));
      return result;
    }
  }

  /// A page of every catalogue product regardless of category, ordered by
  /// name - backs the "All" chip. Same offline-cache fallback as
  /// [fetchByCategory].
  Future<List<CatalogueBrowseItem>> fetchAll({required int offset}) async {
    try {
      final rows = await SupabaseService.supabaseClient
          .from('catalogue_products')
          .select()
          .order('name')
          .range(offset, offset + pageSize - 1);

      final items = (rows as List)
          .map((r) => CatalogueBrowseItem.fromRow(r as Map<String, dynamic>))
          .toList();
      await _cache(items);
      return items;
    } catch (_) {
      if (offset > 0) return [];
      final cached = await _isar.cachedCatalogueProducts.where().findAll();
      return cached.map(CatalogueBrowseItem.fromCached).toList();
    }
  }

  /// A page of products in [category] (pass `'Uncategorised'` for a null
  /// category), ordered by name. Falls back to the local cache when offline
  /// - the cache only ever grows page-by-page as categories are browsed, so
  /// an offline page beyond what's already cached simply comes back empty
  /// rather than erroring.
  Future<List<CatalogueBrowseItem>> fetchByCategory(
    String category, {
    required int offset,
  }) async {
    try {
      final query = SupabaseService.supabaseClient
          .from('catalogue_products')
          .select();
      final filtered = category == _uncategorised
          ? query.isFilter('category', null)
          : query.eq('category', category);
      final rows = await filtered
          .order('name')
          .range(offset, offset + pageSize - 1);

      final items = (rows as List)
          .map((r) => CatalogueBrowseItem.fromRow(r as Map<String, dynamic>))
          .toList();
      await _cache(items);
      return items;
    } catch (_) {
      if (offset > 0) return [];
      final cached = category == _uncategorised
          ? await _isar.cachedCatalogueProducts
                .filter()
                .categoryIsNull()
                .findAll()
          : await _isar.cachedCatalogueProducts
                .filter()
                .categoryEqualTo(category)
                .findAll();
      return cached.map(CatalogueBrowseItem.fromCached).toList();
    }
  }

  /// Searches by name (contains) or exact barcode match, up to [pageSize]
  /// results. Falls back to the local cache when offline.
  Future<List<CatalogueBrowseItem>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final rows = await SupabaseService.supabaseClient
          .from('catalogue_products')
          .select()
          .or('name.ilike.%$trimmed%,barcode.eq.$trimmed')
          .order('name')
          .limit(pageSize);

      final items = (rows as List)
          .map((r) => CatalogueBrowseItem.fromRow(r as Map<String, dynamic>))
          .toList();
      await _cache(items);
      return items;
    } catch (_) {
      final cached = await _isar.cachedCatalogueProducts
          .filter()
          .nameContains(trimmed, caseSensitive: false)
          .or()
          .barcodeEqualTo(trimmed)
          .findAll();
      return cached.map(CatalogueBrowseItem.fromCached).toList();
    }
  }

  /// The single catalogue entry for [barcode], or null if it's not in the
  /// catalogue (network or cache). Used by the scan-to-find flow.
  Future<CatalogueBrowseItem?> findByBarcode(String barcode) async {
    try {
      final rows = await SupabaseService.supabaseClient
          .from('catalogue_products')
          .select()
          .eq('barcode', barcode)
          .limit(1);
      if (rows.isEmpty) return null;
      final item = CatalogueBrowseItem.fromRow(rows.first);
      await _cache([item]);
      return item;
    } catch (_) {
      final cached = await _isar.cachedCatalogueProducts
          .filter()
          .barcodeEqualTo(barcode)
          .findFirst();
      return cached == null ? null : CatalogueBrowseItem.fromCached(cached);
    }
  }

  Future<void> _cache(List<CatalogueBrowseItem> items) async {
    if (items.isEmpty) return;
    final now = DateTime.now();
    await _isar.writeTxn(() async {
      for (final item in items) {
        await _isar.cachedCatalogueProducts.put(
          CachedCatalogueProduct()
            ..barcode = item.barcode
            ..name = item.name
            ..mass = item.mass
            ..category = item.category
            ..imageUrl = item.imageUrl
            ..cachedAt = now,
        );
      }
    });
  }
}
