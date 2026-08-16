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
  /// Filters by `is_verified` - this is the cross-store shared catalogue,
  /// so only verified/approved entries should ever auto-fill a form. This is
  /// distinct from the local Isar lookup a store does for its own products
  /// (ProductRepository.getByBarcode), which has no such filter - a store
  /// can always find its own products regardless of verification.
  static Future<List<Map<String, dynamic>>> fetchCatalogueProduct(
    String barcode,
  ) {
    return supabaseClient
        .from('products')
        .select()
        .eq('barcode', barcode)
        .eq('is_verified', true);
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
  static Future<void> updateLastSeen(String deviceId, String storeId) {
    return supabaseClient.from('devices').upsert({
      'id': deviceId,
      'store_id': storeId,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Fetches verified shared-catalogue products created after [since].
  static Future<List<Map<String, dynamic>>> pullCatalogueUpdates(
    DateTime since,
  ) {
    return supabaseClient
        .from('products')
        .select()
        .gt('created_at', since.toUtc().toIso8601String())
        .eq('is_verified', true);
  }
}
