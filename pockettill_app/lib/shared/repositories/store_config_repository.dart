import 'package:isar/isar.dart';

import '../models/store_config.dart';

/// The single [StoreConfig] record (id is always 1) - this store's identity,
/// device id, and last-synced timestamp.
class StoreConfigRepository {
  StoreConfigRepository({required Isar isar}) : _isar = isar;

  final Isar _isar;

  /// The singleton config, or null if the store hasn't been set up yet.
  Future<StoreConfig?> get() async {
    final config = await _isar.storeConfigs.get(1);
    if (config != null) await _applyImageDefaultsMigration(config);
    return config;
  }

  /// One-time repair for a real Isar gotcha: adding a new bool field with a
  /// non-false Dart-level default (`useCatalogueImages = true`) does not
  /// make Isar honour that default when deserializing a record written
  /// before the field existed - it just reads back `false` (the type's
  /// zero value) regardless of what the class declares. Every install that
  /// registered before this field was added (2026-09-08) was silently
  /// getting "Use PocketTill catalogue images" defaulted to OFF instead of
  /// the intended ON. Guarded by [StoreConfig.imageDefaultsMigrated] so
  /// this only ever corrects it once per device; a pure local fix - the
  /// `stores` row in Supabase already has the correct default from its own
  /// column default, so there's nothing to push.
  Future<void> _applyImageDefaultsMigration(StoreConfig config) async {
    if (config.imageDefaultsMigrated) return;
    config.useCatalogueImages = true;
    config.imageDefaultsMigrated = true;
    await save(config);
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
