import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/event_queue.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/store_config.dart';
import '../models/sync_event.dart';

/// Business logic for [Product] records. Sits between the UI and Isar -
/// screens never touch Isar directly.
class ProductRepository {
  ProductRepository({required Isar isar, required EventQueue eventQueue})
    : _isar = isar,
      _eventQueue = eventQueue;

  final Isar _isar;
  final EventQueue _eventQueue;
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
  Future<void> save(Product product) async {
    final existing = await _isar.products
        .filter()
        .uuidEqualTo(product.uuid)
        .findFirst();
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

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    await _enqueueEvent(
      entityUuid: product.uuid,
      operation: isNew ? 'create' : 'update',
      payload: _toPayload(product),
    );
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

  /// Soft-deletes a product: zeroes its stock rather than removing the row.
  Future<void> delete(String productUuid) async {
    final product = await getByUuid(productUuid);
    if (product == null) return;

    product.stock = 0;
    product.updatedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });

    await _enqueueEvent(
      entityUuid: product.uuid,
      operation: 'delete',
      payload: _toPayload(product),
    );
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
    'category': product.category,
    'unit': product.unit,
    'price': product.price,
    'stock': product.stock,
    'lowStockThreshold': product.lowStockThreshold,
    'isVerified': product.isVerified,
    'createdAt': product.createdAt.toIso8601String(),
    'updatedAt': product.updatedAt?.toIso8601String(),
  };
}
