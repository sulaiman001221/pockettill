import 'package:isar/isar.dart';

part 'store_config.g.dart';

@collection
class StoreConfig {
  Id id = 1; // singleton — only one record ever

  late String storeId;
  late String storeName;
  late String deviceId;
  String? ownerName;
  String? ownerPhone;
  String? address;
  DateTime? lastSyncedAt;

  String? authUserId; // Supabase Auth user UUID
  String? authPhone; // formatted +27 phone used to register
  bool isBetaAdopter = false;
  bool isLoggedIn = false;

  // Local device preferences (Settings > Sound) - not synced to Supabase,
  // never included in any push payload. Both on by default.
  bool scanSoundEnabled = true;
  bool paymentSoundEnabled = true;

  // Settings > Product Images - unlike the sound prefs above, these DO sync
  // to `stores` (as part of the store_profile sync event) so they survive a
  // reinstall. Defaults mirror the `stores` table's own column defaults.
  bool useCatalogueImages = true;
  bool imagesWifiOnly = false;

  // Guards StoreConfigRepository's one-time image-defaults repair - see
  // its doc comment. Deliberately defaults to false (Isar's own zero-value
  // for a bool, which every pre-existing record already reads back as
  // regardless of this class-level initializer) so the repair reliably
  // runs exactly once for every install that predates it.
  bool imageDefaultsMigrated = false;

  // High-water mark for RealtimeStockSyncService's reconnect catch-up query
  // (`stock_events where store_id = ? and synced_at > lastStockEventSyncedAt`)
  // - null means "never run on this device before" ("pull everything" would
  // double-count history already baked into this device's existing local
  // stock; see RealtimeStockSyncService._catchUp, fixed 2026-09-08). Set
  // after every successful catch-up/restore, independent of [lastSyncedAt]
  // (that one tracks the main push/pull cycle, this one tracks stock_events
  // specifically).
  DateTime? lastStockEventSyncedAt;

  // Same high-water-mark idea as [lastStockEventSyncedAt] above, but for
  // RealtimeDataSyncService's catch-up over sales/returns/risk_log (rows
  // missed while this device was offline, not just backgrounded) - compared
  // against each row's own `created_at` there's no server-stamped
  // `synced_at` equivalent on those tables. Null on a device that already
  // has real local data means "this device's own history is already
  // correct as of now" (same reasoning as the stock one), not "pull
  // everything".
  DateTime? lastRealtimeDataSyncedAt;
}
