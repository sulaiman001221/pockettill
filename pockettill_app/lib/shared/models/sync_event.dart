import 'package:isar/isar.dart';

part 'sync_event.g.dart';

@collection
class SyncEvent {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String entityType; // sale | product | credit_customer | credit_tx
  late String entityUuid;
  late String operation; // create | update | delete
  late String payload; // JSON string of the full entity
  late String deviceId;
  late DateTime createdAt;
  bool pushed = false;
  DateTime? pushedAt;

  /// For a `product` update only: the product's `updatedAt` (UTC ISO
  /// string) this device knew about when it made the edit this event
  /// carries - not part of [payload] itself, since that gets pushed to
  /// Supabase verbatim and `products` has no column for it. SyncService
  /// compares this against the row's *current* remote `updated_at` right
  /// before pushing: if the remote value has since moved past this, some
  /// other device's edit reached the server first - since this device
  /// can't have caused that (it hasn't pushed since making this edit), that
  /// alone proves a genuine concurrent edit, logged to risk_log. Null for
  /// every non-product-update event, and for a product's very first edit
  /// (nothing to compare against yet).
  String? baseUpdatedAt;
}
