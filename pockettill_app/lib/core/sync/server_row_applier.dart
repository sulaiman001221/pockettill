import 'package:isar/isar.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/product.dart';
import '../storage/image_cache_service.dart';
import 'pending_changes.dart';
import 'row_mappers.dart';

/// The one place a server `products` / `credit_customers` row is written
/// into local Isar - used by both the periodic/realtime pull and by a
/// device applying the result of its own edit, so both paths follow the same
/// rules:
///
/// - Stock and balance are the server's number **plus this device's own
///   unsent changes** (a sale it hasn't pushed yet is still real).
/// - A record with unsent local edits keeps its local fields (the edit is
///   about to reach the server); only the server-owned numbers refresh.
/// - A copy older than what's already applied is ignored, so a late poll can
///   never undo a newer realtime update.
/// - A record deleted here but not yet on the server is never resurrected.
///
/// Each apply reads the unsent changes and writes inside one Isar write
/// transaction, so a sale recorded at the same moment is either fully
/// counted or fully after - never overwritten by a stale read.
class ServerRowApplier {
  ServerRowApplier(this._isar);

  final Isar _isar;

  /// Returns true if the local row was created or changed.
  Future<bool> applyProduct(Map<String, dynamic> row) async =>
      await applyProducts([row]) > 0;

  /// Applies a page of rows in one transaction (one read of the unsent
  /// changes for the whole page). Returns how many rows changed locally.
  Future<int> applyProducts(List<Map<String, dynamic>> rows) async {
    final staleCacheKeys = <String>[];

    final changedCount = await _isar.writeTxn(() async {
      final pending = await PendingChanges.load(_isar);
      var count = 0;
      for (final row in rows) {
        if (await _applyProductRow(row, pending, staleCacheKeys)) count++;
      }
      return count;
    });

    for (final key in staleCacheKeys) {
      await ImageCacheService.deleteCachedFile(key);
    }
    return changedCount;
  }

  Future<bool> _applyProductRow(
    Map<String, dynamic> row,
    PendingChanges pending,
    List<String> staleCacheKeys,
  ) async {
    final uuid = row['uuid'] as String;
    {
      if (pending.deletedProductUuids.contains(uuid)) return false;

      final existing = await _isar.products
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      final stock =
          (row['stock'] as num).toInt() + (pending.stockDelta[uuid] ?? 0);

      if (existing == null) {
        await _isar.products.put(productFromRow(row)..stock = stock);
        return true;
      }

      final incoming = productFromRow(row);
      final incomingAt = incoming.serverUpdatedAt;
      final knownAt = existing.serverUpdatedAt;
      if (incomingAt != null &&
          knownAt != null &&
          incomingAt.isBefore(knownAt)) {
        return false;
      }

      var changed = false;
      void upd<T>(T current, T next, void Function(T) assign) {
        if (current == next) return;
        assign(next);
        changed = true;
      }

      upd(existing.stock, stock, (v) => existing.stock = v);
      upd(existing.serverVersion, incoming.serverVersion, (v) => existing.serverVersion = v);
      upd(existing.stockVersion, incoming.stockVersion, (v) => existing.stockVersion = v);
      upd(existing.serverUpdatedAt, incomingAt, (v) => existing.serverUpdatedAt = v);

      if (!pending.unsentProductUuids.contains(uuid)) {
        final imageChanged = existing.imageUrl != incoming.imageUrl;
        final barcodeChanged = existing.barcode != incoming.barcode;
        if (imageChanged || barcodeChanged) {
          // The on-device image cache is keyed by barcode, not by URL - a
          // replaced photo or a re-keyed product would otherwise keep
          // showing the old cached file.
          staleCacheKeys.add(existing.barcode);
          existing.cachedImagePath = null;
          if (imageChanged) existing.catalogueSyncedImageUrl = null;
        }
        upd(existing.barcode, incoming.barcode, (v) => existing.barcode = v);
        upd(existing.name, incoming.name, (v) => existing.name = v);
        upd(existing.mass, incoming.mass, (v) => existing.mass = v);
        upd(existing.category, incoming.category, (v) => existing.category = v);
        upd(existing.unit, incoming.unit, (v) => existing.unit = v);
        upd(existing.price, incoming.price, (v) => existing.price = v);
        upd(existing.costPrice, incoming.costPrice, (v) => existing.costPrice = v);
        upd(
          existing.lowStockThreshold,
          incoming.lowStockThreshold,
          (v) => existing.lowStockThreshold = v,
        );
        upd(existing.imageUrl, incoming.imageUrl, (v) => existing.imageUrl = v);
        existing.updatedAt = incoming.updatedAt;
      }

      if (!changed) return false;
      existing.synced = true;
      await _isar.products.put(existing);
      return true;
    }
  }

  /// Returns true if the local row was created or changed.
  Future<bool> applyCustomer(Map<String, dynamic> row) async =>
      await applyCustomers([row]) > 0;

  /// Applies a page of rows in one transaction. Returns how many rows
  /// changed locally.
  Future<int> applyCustomers(List<Map<String, dynamic>> rows) {
    return _isar.writeTxn(() async {
      final pending = await PendingChanges.load(_isar);
      var count = 0;
      for (final row in rows) {
        if (await _applyCustomerRow(row, pending)) count++;
      }
      return count;
    });
  }

  Future<bool> _applyCustomerRow(
    Map<String, dynamic> row,
    PendingChanges pending,
  ) async {
    final uuid = row['uuid'] as String;
    {
      if (pending.deletedCustomerUuids.contains(uuid)) return false;

      final existing = await _isar.creditCustomers
          .filter()
          .uuidEqualTo(uuid)
          .findFirst();
      final balance =
          (row['balance'] as num).toDouble() +
          (pending.balanceDelta[uuid] ?? 0);

      if (existing == null) {
        await _isar.creditCustomers.put(
          creditCustomerFromRow(row)..balance = balance,
        );
        return true;
      }

      final incoming = creditCustomerFromRow(row);
      final incomingAt = incoming.serverUpdatedAt;
      final knownAt = existing.serverUpdatedAt;
      if (incomingAt != null &&
          knownAt != null &&
          incomingAt.isBefore(knownAt)) {
        return false;
      }

      var changed = false;
      void upd<T>(T current, T next, void Function(T) assign) {
        if (current == next) return;
        assign(next);
        changed = true;
      }

      if ((existing.balance - balance).abs() > 0.001) {
        existing.balance = balance;
        changed = true;
      }
      upd(existing.serverVersion, incoming.serverVersion, (v) => existing.serverVersion = v);
      upd(existing.serverUpdatedAt, incomingAt, (v) => existing.serverUpdatedAt = v);
      upd(existing.lastActivityAt, incoming.lastActivityAt, (v) => existing.lastActivityAt = v);

      if (!pending.unsentCustomerUuids.contains(uuid)) {
        upd(existing.name, incoming.name, (v) => existing.name = v);
        upd(existing.phone, incoming.phone, (v) => existing.phone = v);
        upd(existing.creditLimit, incoming.creditLimit, (v) => existing.creditLimit = v);
      }

      if (!changed) return false;
      existing.synced = true;
      await _isar.creditCustomers.put(existing);
      return true;
    }
  }
}
