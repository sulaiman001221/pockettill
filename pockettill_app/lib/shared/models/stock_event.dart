import 'package:isar/isar.dart';

part 'stock_event.g.dart';

/// A local mirror of one `stock_events` row - a durable delta applied to a
/// product's stock, never an absolute value. Stock level is always the sum
/// of every event for that product, which is what makes two devices
/// selling the same product offline safe to reconcile: both deltas land,
/// instead of whichever device syncs last overwriting the other's sale.
///
/// Two ways a row ends up here: (1) this device recorded it locally when it
/// made the change itself (`ProductRepository`'s stock-mutating methods),
/// pushed to Supabase the same way every other synced entity is (see
/// `SyncEvent`, `entityType: 'stock_event'`); or (2) it arrived from
/// another device via `RealtimeStockSyncService` or the reconnect catch-up
/// query, in which case it's already `synced = true` and this device just
/// needs to apply its delta to the matching `Product.stock` once.
@collection
class StockEvent {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String uuid;

  late String productUuid;
  late String deviceId;
  late String changeType; // sale | restock | manual_adjustment | return | initial_stock
  late int quantityDelta;
  String? referenceId;
  late DateTime createdAt;

  /// True for anything already known to Supabase - either pushed by this
  /// device (mirrors `SyncEvent.pushed`) or received from another device.
  /// Only events this device created and hasn't pushed yet are `false`.
  bool synced = false;
}
