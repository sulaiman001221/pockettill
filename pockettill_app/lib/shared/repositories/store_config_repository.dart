import 'package:isar/isar.dart';

import '../models/store_config.dart';

/// The single [StoreConfig] record (id is always 1) - this store's identity,
/// device id, and last-synced timestamp.
class StoreConfigRepository {
  StoreConfigRepository({required Isar isar}) : _isar = isar;

  final Isar _isar;

  /// The singleton config, or null if the store hasn't been set up yet.
  Future<StoreConfig?> get() {
    return _isar.storeConfigs.get(1);
  }

  /// Writes or updates the singleton config (always id = 1).
  Future<void> save(StoreConfig config) async {
    config.id = 1;
    await _isar.writeTxn(() async {
      await _isar.storeConfigs.put(config);
    });
  }

  /// Whether the store has been set up: config exists with a non-empty
  /// storeId.
  Future<bool> isConfigured() async {
    final config = await get();
    return config != null && config.storeId.isNotEmpty;
  }

  /// Stamps lastSyncedAt with the current time on the singleton config.
  Future<void> updateLastSynced() async {
    final config = await get();
    if (config == null) return;

    config.lastSyncedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.storeConfigs.put(config);
    });
  }
}
