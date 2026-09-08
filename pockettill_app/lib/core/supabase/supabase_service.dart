import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes the Supabase client used as PocketTill's background sync
/// target. The UI never talks to Supabase directly or waits on it - all
/// reads/writes go through Isar first.
///
/// [SUPABASE_URL] and [SUPABASE_ANON_KEY] must be supplied at build/run time,
/// e.g. `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
class SupabaseService {
  SupabaseService._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static final Completer<void> _sessionRestored = Completer<void>();

  /// Maps a [SyncEvent.entityType] to the Supabase table it syncs to.
  static const Map<String, String> _entityTables = {
    'sale': 'sales',
    'sale_item': 'sale_items',
    'product': 'products',
    'credit_customer': 'credit_customers',
    'credit_tx': 'credit_transactions',
    'return': 'returns',
    'return_item': 'return_items',
    'store_profile': 'stores',
    'extra_income': 'extra_income',
    'risk_log': 'risk_log',
    'stock_event': 'stock_events',
  };

  /// Initializes the Supabase client.
  static Future<void> init() async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define.',
      );
    }
    await Supabase.initialize(url: url, publishableKey: anonKey);

    // `Supabase.initialize()` resolving does not guarantee
    // `auth.currentSession` is already populated - restoring a persisted
    // session from local storage finishes asynchronously afterward, and is
    // signalled by the SDK's first `onAuthStateChange` event
    // (`AuthChangeEvent.initialSession`, fired exactly once per client
    // lifetime whether or not a session was actually found). Subscribing
    // here, immediately after initialize() returns, guarantees this app
    // never misses it - waiting to subscribe until SplashScreen runs would
    // risk racing past it on a fast device where restoration finishes
    // before Splash even starts checking. See [waitForSessionRestore].
    supabaseClient.auth.onAuthStateChange.first.then((_) {
      if (!_sessionRestored.isCompleted) _sessionRestored.complete();
    });
  }

  /// Resolves once Supabase has finished restoring (or failing to find) a
  /// persisted session - see the subscription set up in [init]. Callers
  /// that decide UI based on [SupabaseClient.currentSession] (e.g.
  /// SplashScreen's routing) must await this first, or they risk reading a
  /// still-null session that simply hasn't finished loading yet - this was
  /// the cause of the app occasionally flashing the login screen before
  /// correcting itself, worse on slower devices where restoration takes
  /// longer. A timeout guards against a stream hiccup hanging the splash
  /// screen forever.
  static Future<void> waitForSessionRestore() {
    return _sessionRestored.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
  }

  /// The initialized Supabase client.
  static SupabaseClient get supabaseClient => Supabase.instance.client;

  /// Looks up a shared-catalogue product by [barcode]. Returns an empty list
  /// if no match exists.
  ///
  /// Reads from `catalogue_products` - the admin-moderated, cross-store
  /// shared catalogue, structurally separate from a store's own `products`
  /// table, so every row here is already verified by construction. This is
  /// distinct from the local Isar lookup a store does for its own products
  /// (ProductRepository.getByBarcode), which reads private inventory data
  /// instead.
  static Future<List<Map<String, dynamic>>> fetchCatalogueProduct(
    String barcode,
  ) {
    return supabaseClient
        .from('catalogue_products')
        .select()
        .eq('barcode', barcode);
  }

  /// Upserts (or deletes) a batch of sync events to their Supabase tables.
  ///
  /// Each event map is expected to contain:
  /// - `entityType`: one of `sale`, `sale_item`, `product`,
  ///   `credit_customer`, `credit_tx`, `return`, `return_item`
  /// - `operation`: `create`, `update`, or `delete`
  /// - `entityUuid`: the row's primary key
  /// - `payload`: the decoded row data (used for `create`/`update`)
  ///
  /// Events are grouped by their destination table so each table only needs
  /// a single upsert/delete call per batch.
  static Future<void> pushEvents(List<Map<String, dynamic>> events) async {
    // Events arrive oldest-first and each payload carries the full row, so
    // only a row's newest event matters - and Postgres rejects an upsert
    // batch that touches the same row twice ("ON CONFLICT DO UPDATE command
    // cannot affect row a second time"). Collapse each batch to its final
    // state per row before pushing; this also makes create-then-delete send
    // just the delete, and delete-then-recreate (undo) send just the create.
    final latestByRow = <String, Map<String, dynamic>>{};
    for (final event in events) {
      final table = _entityTables[event['entityType']];
      if (table == null) continue;
      latestByRow['$table:${event['entityUuid']}'] = event;
    }

    final upsertsByTable = <String, List<Map<String, dynamic>>>{};
    final deletesByTable = <String, List<String>>{};

    for (final event in latestByRow.values) {
      final table = _entityTables[event['entityType']]!;

      if (event['operation'] == 'delete') {
        (deletesByTable[table] ??= []).add(event['entityUuid'] as String);
      } else {
        final payload = Map<String, dynamic>.from(
          event['payload'] as Map<Object?, Object?>,
        );
        (upsertsByTable[table] ??= []).add(_snakeCaseKeys(payload));
      }
    }

    for (final entry in upsertsByTable.entries) {
      await supabaseClient.from(entry.key).upsert(entry.value);
    }
    for (final entry in deletesByTable.entries) {
      await supabaseClient
          .from(entry.key)
          .delete()
          .inFilter('uuid', entry.value);
    }
  }

  /// Converts camelCase payload keys to the snake_case column names Postgres
  /// uses. Events queued by app versions that serialized camelCase payloads
  /// survive in Isar across updates, so this must handle both conventions -
  /// snake_case keys pass through unchanged.
  static Map<String, dynamic> _snakeCaseKeys(Map<String, dynamic> payload) {
    return payload.map((key, value) {
      final snakeKey = key.replaceAllMapped(
        RegExp('[A-Z]'),
        (match) => '_${match[0]!.toLowerCase()}',
      );
      return MapEntry(snakeKey, value);
    });
  }

  /// Marks a device as having just synced, creating its `devices` row on
  /// first sync (there is no separate device-registration step).
  ///
  /// Deliberately does not touch `device_name` here - login already stamps
  /// it, and re-sending it on every sync would just be redundant traffic
  /// for a value that never changes for a given physical device.
  static Future<void> updateLastSeen(String deviceId, String storeId) {
    return supabaseClient.from('devices').upsert({
      'id': deviceId,
      'store_id': storeId,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Whether this exact (deviceId, storeId) pairing's `devices.verified_at`
  /// has been cleared - i.e. the owner tapped "Log out this device" for it
  /// in Settings > Active Devices. Same underlying check as
  /// `AuthService._isDeviceVerified`, just inverted and named for what
  /// [SyncService] uses it for. A direct table read (not an RPC) works
  /// fine here since this device's own session still satisfies
  /// `devices_store_all`'s RLS - unlike the old `active_device_id` scheme,
  /// nothing here revokes the JWT itself, only the app-level check.
  /// Best-effort: any failure returns false, since wrongly reporting "you
  /// were revoked" would sign out a legitimate user over what might just be
  /// a connectivity blip.
  static Future<bool> isThisDeviceRevoked({
    required String storeId,
    required String deviceId,
  }) async {
    try {
      final row = await supabaseClient
          .from('devices')
          .select('verified_at')
          .eq('id', deviceId)
          .eq('store_id', storeId)
          .maybeSingle();
      return row != null && row['verified_at'] == null;
    } catch (_) {
      return false;
    }
  }

  /// Every `devices` row for [storeId] - backs Settings > Active Devices.
  static Future<List<Map<String, dynamic>>> fetchStoreDevices(
    String storeId,
  ) {
    return supabaseClient
        .from('devices')
        .select()
        .eq('store_id', storeId)
        .order('last_seen_at', ascending: false);
  }

  /// Clears `devices.verified_at` for one (deviceId, storeId) pairing - the
  /// "Log out this device" action. That device's own next sync/app-open
  /// notices via [isThisDeviceRevoked]/`AuthService.checkDeviceTrust` and
  /// gets challenged with OTP again, same as a genuinely new device.
  static Future<void> revokeDevice({
    required String storeId,
    required String deviceId,
  }) {
    return supabaseClient
        .from('devices')
        .update({'verified_at': null})
        .eq('id', deviceId)
        .eq('store_id', storeId);
  }

  /// `stock_events` rows for [storeId] recorded by a device other than
  /// [excludingDeviceId], with `synced_at` after [since] - the reconnect
  /// catch-up query [RealtimeStockSyncService] runs before re-subscribing,
  /// so a gap while offline (or while a Realtime channel was down) doesn't
  /// leave this device's stock silently behind. Own-device events are
  /// excluded here for the same reason [RealtimeStockSyncService] filters
  /// them out of the live channel too - this device already applied its
  /// own deltas locally the moment it created them.
  static Future<List<Map<String, dynamic>>> fetchMissedStockEvents({
    required String storeId,
    required String excludingDeviceId,
    DateTime? since,
  }) {
    var query = supabaseClient
        .from('stock_events')
        .select()
        .eq('store_id', storeId)
        .neq('device_id', excludingDeviceId);
    if (since != null) {
      query = query.gt('synced_at', since.toUtc().toIso8601String());
    }
    return query.order('synced_at');
  }

  /// The most recent `stock_events.synced_at` across the whole store, or
  /// null if it has none yet - used to seed
  /// [StoreConfig.lastStockEventSyncedAt] the very first time
  /// [RealtimeStockSyncService] runs on a device that already has real
  /// local data (as opposed to a fresh restore), so its existing local
  /// stock - already correct as of right now, from before stock_events
  /// existed - isn't perturbed by retroactively re-applying old events
  /// (e.g. double-counting the `initial_stock` migration backfill). Mirrors
  /// [RestoreService]'s own same-purpose watermark seeding on a fresh
  /// restore.
  static Future<DateTime?> fetchLatestStockEventSyncedAt(
    String storeId,
  ) async {
    final rows = await supabaseClient
        .from('stock_events')
        .select('synced_at')
        .eq('store_id', storeId)
        .order('synced_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['synced_at'] as String).toLocal();
  }

  /// Fetches verified shared-catalogue products created after [since].
  static Future<List<Map<String, dynamic>>> pullCatalogueUpdates(
    DateTime since,
  ) {
    return supabaseClient
        .from('catalogue_products')
        .select()
        .gt('created_at', since.toUtc().toIso8601String());
  }

  /// Maps each of [barcodes] that has an admin-enhanced catalogue image
  /// (`catalogue_products.is_image_enhanced = true`) to that image's URL -
  /// backs [ImageSyncService]'s background auto-sync. A barcode with no
  /// catalogue entry, or one that's only ever had the plain store-submitted
  /// photo, simply doesn't appear in the result.
  static Future<Map<String, String>> fetchEnhancedCatalogueImages(
    List<String> barcodes,
  ) async {
    if (barcodes.isEmpty) return {};
    final rows = await supabaseClient
        .from('catalogue_products')
        .select('barcode, image_url')
        .inFilter('barcode', barcodes)
        .eq('is_image_enhanced', true);

    final result = <String, String>{};
    for (final row in rows) {
      final url = row['image_url'] as String?;
      if (url != null && url.isNotEmpty) {
        result[row['barcode'] as String] = url;
      }
    }
    return result;
  }
}
