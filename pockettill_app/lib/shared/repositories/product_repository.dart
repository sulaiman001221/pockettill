import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/image_cache_service.dart';
import '../../core/sync/event_queue.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/store_config.dart';
import '../models/sync_event.dart';
import 'catalogue_browse_repository.dart';
import 'risk_log_repository.dart';

/// Business logic for [Product] records. Sits between the UI and Isar -
/// screens never touch Isar directly.
class ProductRepository {
  ProductRepository({
    required Isar isar,
    required EventQueue eventQueue,
    required RiskLogRepository riskLog,
  }) : _isar = isar,
       _eventQueue = eventQueue,
       _riskLog = riskLog;

  final Isar _isar;
  final EventQueue _eventQueue;
  final RiskLogRepository _riskLog;
  final _uuid = const Uuid();

  /// All products, ordered by name ascending.
  Future<List<Product>> getAll() {
    return _isar.products.where().sortByName().findAll();
  }

  /// The product matching [barcode], or null if none exists.
  Future<Product?> getByBarcode(String barcode) {
    return _isar.products.filter().barcodeEqualTo(barcode).findFirst();
  }

  /// The product matching [uuid], or null if none exists.
  Future<Product?> getByUuid(String uuid) {
    return _isar.products.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Searches name and barcode (case-insensitive), up to 20 results.
  Future<List<Product>> search(String query) {
    return _isar.products
        .filter()
        .nameContains(query, caseSensitive: false)
        .or()
        .barcodeContains(query, caseSensitive: false)
        .limit(20)
        .findAll();
  }

  /// Products at or below their low-stock threshold, lowest stock first.
  Future<List<Product>> getLowStock() async {
    // stock <= lowStockThreshold compares two fields on the same row, which
    // Isar filters can't express directly - filter in memory instead.
    final all = await _isar.products.where().findAll();
    final lowStock = all.where((p) => p.stock <= p.lowStockThreshold).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
    return lowStock;
  }

  /// Products that haven't appeared in any sale in the last [days] days.
  Future<List<Product>> getDeadStock({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentSales = await _isar.sales
        .filter()
        .createdAtGreaterThan(cutoff)
        .findAll();
    final recentSaleUuids = recentSales.map((sale) => sale.uuid).toSet();

    final soldProductUuids = <String>{};
    if (recentSaleUuids.isNotEmpty) {
      final recentItems = await _isar.saleItems
          .filter()
          .anyOf(recentSaleUuids, (q, String uuid) => q.saleUuidEqualTo(uuid))
          .findAll();
      soldProductUuids.addAll(recentItems.map((item) => item.productUuid));
    }

    final allProducts = await _isar.products.where().findAll();
    return allProducts
        .where((product) => !soldProductUuids.contains(product.uuid))
        .toList();
  }

  /// Writes [product] to Isar and enqueues a sync event.
  ///
  /// Looks up any existing row by [Product.uuid] first: if found, this is an
  /// update (the existing Isar [Id] is reused so `put` replaces the row
  /// instead of inserting a duplicate, and [Product.createdAt] is
  /// preserved); otherwise a uuid is generated if needed and this is a
  /// create.
  ///
  /// This is the only place the app ever calls to edit an existing product
  /// (add_product_screen.dart, for both create and edit), so an update here
  /// is always a direct, manual edit - never a sale/return/quick-restock,
  /// which all go through [adjustStock] instead. That's what makes it safe
  /// to log a stock drop or price change here as a Risk Log entry without
  /// needing to distinguish the caller.
  Future<void> save(Product product) async {
    // An empty uuid always means "not yet created" - never match it against
    // another row (a stray empty-uuid row in the data would otherwise get
    // silently overwritten by every subsequent new product).
    final existing = product.uuid.isEmpty
        ? null
        : await _isar.products.filter().uuidEqualTo(product.uuid).findFirst();
    final isNew = existing == null;
    final now = DateTime.now();

    if (isNew) {
      if (product.uuid.isEmpty) {
        product.uuid = _uuid.v4();
      }
      product.createdAt = now;
    } else {
      product.id = existing.id;
      product.createdAt = existing.createdAt;
      product.updatedAt = now;
    }

    // If the image actually changed, any previously cached file is now
    // stale - drop it (and forget the now-wrong cachedImagePath) so the
    // next display re-downloads the new one instead of silently
    // continuing to show the old cached bytes forever. The on-device cache
    // has no other way to notice its bytes no longer match imageUrl: it's
    // keyed purely by barcode, not by which URL was last fetched. Found
    // 2026-09-08 - Stock kept showing the pre-edit photo after a manual
    // re-upload via Add/Edit Product, even though the edit screen's own
    // preview (which reads imageUrl fresh over the network) showed the
    // new one correctly.
    if (!isNew && existing.imageUrl != product.imageUrl) {
      await ImageCacheService.deleteCachedFile(product.barcode);
      product.cachedImagePath = null;
    }

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    await _enqueueEvent(
      entityUuid: product.uuid,
      operation: isNew ? 'create' : 'update',
      payload: _toPayload(product),
    );

    if (existing != null) {
      await _recordEditRiskEvents(before: existing, after: product);
    }
  }

  /// Updates just [Product.cachedImagePath] for [productUuid] - a pure
  /// local-cache bookkeeping write, deliberately bypassing [save]'s sync
  /// event/risk-log logic: a device-local file path means nothing to sync
  /// (another device can't read this device's disk) and isn't an edit
  /// worth auditing.
  Future<void> updateCachedImagePath(String productUuid, String path) async {
    final product = await getByUuid(productUuid);
    if (product == null) return;
    product.cachedImagePath = path;
    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });
  }

  /// Imports [items] from Catalogue Browse as new products - stock 0,
  /// price from [prices] (keyed by barcode) or 0 if that barcode has no
  /// entry ("Set prices later" is an explicit supported path, so 0 has to
  /// be a valid starting price rather than something [save] rejects).
  ///
  /// Callers must only invoke this once the import is actually confirmed
  /// (e.g. the price-setting screen's "Save Prices"/"Set prices later"
  /// buttons, never just landing on that screen or backing out of it) -
  /// this is the one place products actually get created, so calling it
  /// eagerly before the user confirms is what previously let a bare back-arrow
  /// tap silently add products nobody approved.
  ///
  /// Duplicate barcodes already in stock are skipped rather than
  /// overwritten - the browse screen already disables already-owned items,
  /// this is just the same guarantee enforced server-side against a stale
  /// selection.
  Future<List<Product>> importFromCatalogue(
    List<CatalogueBrowseItem> items, {
    Map<String, double>? prices,
  }) async {
    final imported = <Product>[];
    for (final item in items) {
      final alreadyOwned = await getByBarcode(item.barcode);
      if (alreadyOwned != null) continue;

      final product = Product()
        ..uuid = _uuid.v4()
        ..barcode = item.barcode
        ..name = item.name
        ..mass = item.mass
        ..category = item.category
        ..imageUrl = item.imageUrl
        ..price = prices?[item.barcode] ?? 0
        ..stock = 0;
      await save(product);
      imported.add(product);
    }
    return imported;
  }

  Future<void> _recordEditRiskEvents({
    required Product before,
    required Product after,
  }) async {
    if (after.stock < before.stock) {
      await _riskLog.record(
        type: 'manual_stock_reduction',
        description: 'Stock manually reduced for ${after.name}',
        beforeValue: '${before.stock}',
        afterValue: '${after.stock}',
        entityName: after.name,
      );
    }
    if (after.price != before.price) {
      await _riskLog.record(
        type: 'price_changed',
        description: 'Selling price changed for ${after.name}',
        beforeValue: 'R${before.price.toStringAsFixed(2)}',
        afterValue: 'R${after.price.toStringAsFixed(2)}',
        entityName: after.name,
      );
    }
  }

  /// Applies [delta] to the product's stock (negative for sales) and saves.
  Future<void> adjustStock(String productUuid, int delta) async {
    final product = await getByUuid(productUuid);
    if (product == null) {
      throw StateError('Product $productUuid not found.');
    }

    product.stock += delta;
    product.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    await _enqueueEvent(
      entityUuid: product.uuid,
      operation: 'update',
      payload: _toPayload(product),
    );
  }

  /// Deletes a product row outright.
  ///
  /// Safe to always be a plain delete: a store's own `products` row is
  /// purely private inventory data now (the shared, admin-moderated
  /// catalogue lives entirely in `catalogue_products`, a structurally
  /// separate table stores can't write to at all - see
  /// SupabaseService.fetchCatalogueProduct), so nothing else can ever
  /// depend on this exact row.
  Future<void> delete(String productUuid) async {
    final product = await getByUuid(productUuid);
    if (product == null) return;

    await _isar.writeTxn(() async {
      await _isar.products.delete(product.id);
    });
    await ImageCacheService.deleteCachedFile(product.barcode);

    await _enqueueEvent(
      entityUuid: product.uuid,
      operation: 'delete',
      payload: _toPayload(product),
    );

    // Only worth a Risk Log entry if this product actually had sale
    // history - deleting a product that was just added (e.g. a
    // still-unverified catalogue submission, or a duplicate/mis-scan
    // corrected right away) isn't suspicious, so it shouldn't clutter the
    // Risk Log the way removing established, previously-sold stock would.
    final everSold =
        await _isar.saleItems
            .filter()
            .productUuidEqualTo(product.uuid)
            .count() >
        0;
    if (everSold) {
      await _riskLog.record(
        type: 'product_deleted',
        description: 'Product deleted: ${product.name}',
        beforeValue: '${product.stock} in stock',
        afterValue: null,
        entityName: product.name,
      );
    }
  }

  Future<void> _enqueueEvent({
    required String entityUuid,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final deviceId = (await _isar.storeConfigs.get(1))?.deviceId ?? '';
    final event = SyncEvent()
      ..uuid = _uuid.v4()
      ..entityType = 'product'
      ..entityUuid = entityUuid
      ..operation = operation
      ..payload = jsonEncode(payload)
      ..deviceId = deviceId
      ..createdAt = DateTime.now();
    await _eventQueue.enqueue(event);
  }

  Map<String, dynamic> _toPayload(Product product) => {
    'uuid': product.uuid,
    'barcode': product.barcode,
    'name': product.name,
    'mass': product.mass,
    'category': product.category,
    'unit': product.unit,
    'price': product.price,
    'cost_price': product.costPrice,
    'stock': product.stock,
    'low_stock_threshold': product.lowStockThreshold,
    'image_url': product.imageUrl,
    'created_at': product.createdAt.toUtc().toIso8601String(),
    'updated_at': product.updatedAt?.toUtc().toIso8601String(),
  };
}
