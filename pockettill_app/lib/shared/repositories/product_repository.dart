import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/image_cache_service.dart';
import '../../core/sync/event_queue.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/stock_event.dart';
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

  /// Writes [product] to Isar and queues what the server needs to hear.
  ///
  /// Looks up any existing row by [Product.uuid] first: if found, this is a
  /// manual edit (the existing Isar [Id] is reused so `put` replaces the row
  /// instead of inserting a duplicate); otherwise it's a create.
  ///
  /// A manual edit is queued as one `_edit` event carrying only the fields
  /// that actually changed, each with the value this device saw before the
  /// change. The server applies a field only if nobody else changed it in the
  /// meantime (see `apply_product_edit`); a field that lost that race is
  /// reverted here on the next sync and logged in the Risk Log.
  ///
  /// [initial] is a snapshot of the product as the form opened. Only fields
  /// that differ between it and [product] count as this person's edit - a
  /// field they never touched isn't sent, so a change another device made
  /// while the form was open can't be overwritten by saving it. Stock is sent
  /// as a *change* (typed quantity minus the quantity the form opened with),
  /// never as an absolute number, so a sale made while the form was open
  /// isn't undone by saving it either.
  ///
  /// This is the only place the app ever calls to edit an existing product
  /// by hand (add_product_screen.dart, for both create and edit), so an update
  /// here is always a direct, manual edit - never a sale/return/quick-restock
  /// (those go through [adjustStock] or the ledger directly) and never a
  /// background image sync (see [updateImageUrl]). That's what makes it safe
  /// to log a stock drop or price change here as a Risk Log entry without
  /// needing to distinguish the caller.
  Future<void> save(Product product, {Product? initial}) async {
    // An empty uuid always means "not yet created" - never match it against
    // another row (a stray empty-uuid row in the data would otherwise get
    // silently overwritten by every subsequent new product).
    final existing = product.uuid.isEmpty
        ? null
        : await _isar.products.filter().uuidEqualTo(product.uuid).findFirst();
    final now = DateTime.now();

    if (existing == null) {
      if (product.uuid.isEmpty) {
        product.uuid = _uuid.v4();
      }
      product.createdAt = now;
      await _isar.writeTxn(() async {
        await _isar.products.put(product);
      });

      // "Undo" of a delete that hasn't reached the server yet: the server
      // still has the row, so just cancel the delete and bring the local
      // row back - re-creating it would count its stock a second time.
      final pendingDelete = await _pendingProductEvent(
        product.uuid,
        operation: 'delete',
      );
      if (pendingDelete != null) {
        await _eventQueue.discard([pendingDelete.uuid]);
        return;
      }

      await _enqueueEvent(
        entityUuid: product.uuid,
        operation: 'create',
        payload: _toPayload(product),
      );
      // A brand-new product can start with a non-zero stock (the owner typed
      // an initial quantity) - the server starts every product at zero and
      // counts this event, the same as any other change to stock.
      if (product.stock != 0) {
        await _recordStockEvent(
          productUuid: product.uuid,
          changeType: 'initial_stock',
          quantityDelta: product.stock,
        );
      }
      return;
    }

    final started = initial ?? existing;
    final before = _snapshot(existing);

    // Start from the row as it is right now and apply only what this person
    // changed - a three-way merge of (what they started from, what they
    // typed, what's stored now).
    final base = <String, dynamic>{};
    final changes = <String, dynamic>{};
    void track<T>(String key, T startedWith, T typed, void Function(T) apply) {
      if (startedWith == typed) return;
      base[key] = startedWith;
      changes[key] = typed;
      apply(typed);
    }

    track('barcode', started.barcode, product.barcode, (v) => existing.barcode = v);
    track('name', started.name, product.name, (v) => existing.name = v);
    track('mass', started.mass, product.mass, (v) => existing.mass = v);
    track('category', started.category, product.category, (v) => existing.category = v);
    track('unit', started.unit, product.unit, (v) => existing.unit = v);
    track('price', started.price, product.price, (v) => existing.price = v);
    track('cost_price', started.costPrice, product.costPrice, (v) => existing.costPrice = v);
    track(
      'low_stock_threshold',
      started.lowStockThreshold,
      product.lowStockThreshold,
      (v) => existing.lowStockThreshold = v,
    );

    // Keep any sale/return that landed while the form was open.
    final stockDelta = product.stock - started.stock;
    existing.stock += stockDelta;
    existing.updatedAt = now;

    // If the image actually changed, any previously cached file is now
    // stale - drop it (and forget the now-wrong cachedImagePath) so the
    // next display re-downloads the new one instead of silently
    // continuing to show the old cached bytes forever. The on-device cache
    // has no other way to notice its bytes no longer match imageUrl: it's
    // keyed purely by barcode, not by which URL was last fetched.
    final imageChanged = started.imageUrl != product.imageUrl;
    if (imageChanged) {
      await ImageCacheService.deleteCachedFile(before.barcode);
      existing.imageUrl = product.imageUrl;
      existing.cachedImagePath = null;
    }

    await _isar.writeTxn(() async {
      await _isar.products.put(existing);
    });

    final pendingCreate = await _pendingProductEvent(
      existing.uuid,
      operation: 'create',
    );
    if (pendingCreate != null) {
      // The server has never seen this product, so nobody can be racing this
      // edit - fold it into the create that's still waiting to be sent.
      await _replacePayload(pendingCreate, _toPayload(existing));
      if (stockDelta != 0) {
        await _recordStockEvent(
          productUuid: existing.uuid,
          changeType: 'manual_adjustment',
          quantityDelta: stockDelta,
        );
      }
    } else {
      if (changes.isNotEmpty || stockDelta != 0) {
        await _queueEdit(
          existing.uuid,
          base: base,
          changes: changes,
          stockBaseVersion: existing.stockVersion,
          stockDelta: stockDelta,
        );
      }
      if (imageChanged) {
        await _queueImageUpdate(existing.uuid, existing.imageUrl);
      }
    }

    await _recordEditRiskEvents(before: before, after: existing);
  }

  /// A detached copy of the fields a manual edit can change, for comparing
  /// "before" against "after" once the row itself has been updated.
  Product _snapshot(Product p) => Product()
    ..uuid = p.uuid
    ..barcode = p.barcode
    ..name = p.name
    ..mass = p.mass
    ..category = p.category
    ..unit = p.unit
    ..price = p.price
    ..costPrice = p.costPrice
    ..stock = p.stock
    ..lowStockThreshold = p.lowStockThreshold
    ..imageUrl = p.imageUrl
    ..createdAt = p.createdAt;

  /// Queues (or merges into an already-queued) manual edit for [uuid]. Two
  /// edits made before the first one syncs are one edit as far as the server
  /// is concerned - sent separately, the second would be checked against a
  /// starting point the first already moved and read as a conflict with
  /// itself.
  Future<void> _queueEdit(
    String uuid, {
    required Map<String, dynamic> base,
    required Map<String, dynamic> changes,
    required int stockBaseVersion,
    required int stockDelta,
  }) async {
    final pending = await _pendingProductEvent(
      uuid,
      operation: 'update',
      isEdit: true,
    );
    if (pending == null) {
      await _enqueueEvent(
        entityUuid: uuid,
        operation: 'update',
        payload: {
          '_edit': {
            'base': base,
            'changes': changes,
            'base_stock_version': stockBaseVersion,
            'stock_delta': stockDelta,
            'edit_id': _uuid.v4(),
          },
        },
      );
      return;
    }

    final payload = jsonDecode(pending.payload) as Map<String, dynamic>;
    final edit = Map<String, dynamic>.from(payload['_edit'] as Map);
    final mergedBase = Map<String, dynamic>.from(edit['base'] as Map);
    final mergedChanges = Map<String, dynamic>.from(edit['changes'] as Map);
    changes.forEach((key, value) {
      mergedBase.putIfAbsent(key, () => base[key]);
      mergedChanges[key] = value;
    });
    // A field put back to where it started is no longer an edit at all.
    for (final key in mergedChanges.keys.toList()) {
      if (mergedChanges[key] == mergedBase[key]) {
        mergedChanges.remove(key);
        mergedBase.remove(key);
      }
    }
    final mergedDelta =
        ((edit['stock_delta'] as num?)?.toInt() ?? 0) + stockDelta;

    if (mergedChanges.isEmpty && mergedDelta == 0) {
      await _eventQueue.discard([pending.uuid]);
      return;
    }
    edit['base'] = mergedBase;
    edit['changes'] = mergedChanges;
    edit['stock_delta'] = mergedDelta;
    await _replacePayload(pending, {'_edit': edit});
  }

  /// The photo is last-write-wins and deliberately outside the conflict
  /// check: a single-column update, never the whole row.
  Future<void> _queueImageUpdate(String uuid, String? imageUrl) async {
    final pending = await _pendingProductEvent(uuid, operation: 'image_update');
    if (pending != null) {
      await _replacePayload(pending, {'uuid': uuid, 'image_url': imageUrl});
      return;
    }
    await _enqueueEvent(
      entityUuid: uuid,
      operation: 'image_update',
      payload: {'uuid': uuid, 'image_url': imageUrl},
    );
  }

  Future<SyncEvent?> _pendingProductEvent(
    String uuid, {
    required String operation,
    bool isEdit = false,
  }) async {
    final candidates = await _isar.syncEvents
        .filter()
        .pushedEqualTo(false)
        .and()
        .entityTypeEqualTo('product')
        .and()
        .entityUuidEqualTo(uuid)
        .and()
        .operationEqualTo(operation)
        .sortByCreatedAtDesc()
        .findAll();
    for (final event in candidates) {
      if (!isEdit) return event;
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      if (payload['_edit'] != null) return event;
    }
    return null;
  }

  Future<void> _replacePayload(
    SyncEvent event,
    Map<String, dynamic> payload,
  ) async {
    event.payload = jsonEncode(payload);
    await _isar.writeTxn(() async {
      await _isar.syncEvents.put(event);
    });
  }

  /// Records where this device's copy of the photo came from - device-local
  /// bookkeeping only, never synced. Re-reads the product first so a stale
  /// in-memory copy can't overwrite a sale recorded since it was loaded.
  Future<void> updateCatalogueSyncedImageUrl(
    String productUuid,
    String? url,
  ) async {
    final product = await getByUuid(productUuid);
    if (product == null) return;
    product.catalogueSyncedImageUrl = url;
    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });
  }

  /// Sets a product's photo without going through [save] - for the
  /// background catalogue image sync, which must never be treated as a
  /// person editing the product (and so never raises or loses an edit
  /// conflict). [catalogueSyncedImageUrl] is this device's own bookkeeping
  /// for where the image came from, never synced.
  Future<void> updateImageUrl(
    String productUuid,
    String? imageUrl, {
    String? catalogueSyncedImageUrl,
  }) async {
    final product = await getByUuid(productUuid);
    if (product == null) return;

    final changed = product.imageUrl != imageUrl;
    if (changed) {
      await ImageCacheService.deleteCachedFile(product.barcode);
      product.cachedImagePath = null;
    }
    product.imageUrl = imageUrl;
    product.catalogueSyncedImageUrl = catalogueSyncedImageUrl;
    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });
    if (!changed) return;

    final pendingCreate = await _pendingProductEvent(
      productUuid,
      operation: 'create',
    );
    if (pendingCreate != null) {
      await _replacePayload(pendingCreate, _toPayload(product));
      return;
    }
    await _queueImageUpdate(productUuid, imageUrl);
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

  /// Applies [delta] to the product's stock (negative for sales) - a plain
  /// ledger fact: the server adds it to whatever else has been recorded, so
  /// it can never conflict with another device's sale or restock.
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

    await _recordStockEvent(
      productUuid: product.uuid,
      changeType: 'manual_adjustment',
      quantityDelta: delta,
    );
  }

  /// Deletes a product row outright.
  ///
  /// Safe to always be a plain delete: a store's own `products` row is
  /// purely private inventory data now (the shared, admin-moderated
  /// catalogue lives entirely in `catalogue_products`, a structurally
  /// separate table stores can't write to at all - see
  /// SupabaseService.fetchCatalogueProduct). Its own `stock_events` rows
  /// (virtually every product has at least an `initial_stock` one) cascade
  /// away with it remotely - see the FK note in SCHEMA_TRUTH.md - so this
  /// doesn't need to clean those up itself. That FK used to be plain `NO
  /// ACTION`, which meant almost every product delete permanently violated
  /// it and retried forever with no way to succeed; fixed 2026-09-12.
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
    String? baseUpdatedAt,
  }) async {
    final deviceId = (await _isar.storeConfigs.get(1))?.deviceId ?? '';
    final event = SyncEvent()
      ..uuid = _uuid.v4()
      ..entityType = 'product'
      ..entityUuid = entityUuid
      ..operation = operation
      ..payload = jsonEncode(payload)
      ..deviceId = deviceId
      ..createdAt = DateTime.now()
      ..baseUpdatedAt = baseUpdatedAt;
    await _eventQueue.enqueue(event);
  }

  /// Records a durable `stock_events` delta locally and enqueues it for
  /// sync - see [StockEvent]'s doc comment for why every stock-changing
  /// path does this (not just here: [SaleRepository]/[ReturnRepository]
  /// call the same pattern directly). A no-op for a zero delta - nothing
  /// changed, nothing to record.
  ///
  /// Must be called from within an already-open `isar.writeTxn()` - Isar
  /// (3.1.0) throws `IsarError: Isar does not support nesting
  /// transactions` if this opens its own while one is already active, which
  /// is exactly how [SaleRepository.completeSale] and
  /// [ReturnRepository.processReturn] call it (from inside their own single
  /// all-effects transaction). Found 2026-09-08 - this bug made every sale
  /// and return fail outright ("Could not make a sale") once those call
  /// sites were added. [ProductRepository]'s own callers
  /// ([save]/[adjustStock]) are outside any transaction at their call site,
  /// so they go through [_recordStockEvent] instead, which opens one.
  static Future<void> recordStockEvent({
    required Isar isar,
    required String productUuid,
    required String changeType,
    required int quantityDelta,
    String? referenceId,
  }) async {
    if (quantityDelta == 0) return;
    final deviceId = (await isar.storeConfigs.get(1))?.deviceId ?? '';
    final now = DateTime.now();

    final stockEvent = StockEvent()
      ..uuid = const Uuid().v4()
      ..productUuid = productUuid
      ..deviceId = deviceId
      ..changeType = changeType
      ..quantityDelta = quantityDelta
      ..referenceId = referenceId
      ..createdAt = now;

    final syncEvent = SyncEvent()
      ..uuid = const Uuid().v4()
      ..entityType = 'stock_event'
      ..entityUuid = stockEvent.uuid
      ..operation = 'create'
      ..payload = jsonEncode(_stockEventPayload(stockEvent))
      ..deviceId = deviceId
      ..createdAt = now;

    await isar.stockEvents.put(stockEvent);
    await isar.syncEvents.put(syncEvent);
  }

  /// Wraps [recordStockEvent] in its own transaction, for callers (this
  /// repository's own [save]/[adjustStock]) that aren't already inside one
  /// at their call site.
  Future<void> _recordStockEvent({
    required String productUuid,
    required String changeType,
    required int quantityDelta,
    String? referenceId,
  }) {
    return _isar.writeTxn(
      () => recordStockEvent(
        isar: _isar,
        productUuid: productUuid,
        changeType: changeType,
        quantityDelta: quantityDelta,
        referenceId: referenceId,
      ),
    );
  }

  static Map<String, dynamic> _stockEventPayload(StockEvent event) => {
    // Supabase's primary key column for stock_events is `id`, not `uuid`
    // (unlike every other synced table) - see the migration. Matching that
    // exact key here is what makes SupabaseService.pushEvents' upsert
    // target the right column.
    'id': event.uuid,
    'product_id': event.productUuid,
    'device_id': event.deviceId,
    'change_type': event.changeType,
    'quantity_delta': event.quantityDelta,
    'reference_id': event.referenceId,
    'created_at': event.createdAt.toUtc().toIso8601String(),
  };

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
