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

  /// Maps a [SyncEvent.entityType] to the Supabase table it syncs to.
  static const Map<String, String> _entityTables = {
    'sale': 'sales',
    'sale_item': 'sale_items',
    'product': 'products',
    'credit_customer': 'credit_customers',
    'credit_tx': 'credit_transactions',
  };

  /// Initializes the Supabase client.
  static Future<void> init() async {
    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be provided via --dart-define.',
      );
    }
    await Supabase.initialize(url: url, publishableKey: anonKey);
  }

  /// The initialized Supabase client.
  static SupabaseClient get supabaseClient => Supabase.instance.client;

  /// Looks up a shared-catalogue product by [barcode]. Returns an empty list
  /// if no match exists.
  static Future<List<Map<String, dynamic>>> fetchCatalogueProduct(
    String barcode,
  ) {
    return supabaseClient.from('products').select().eq('barcode', barcode);
  }

  /// Upserts (or deletes) a batch of sync events to their Supabase tables.
  ///
  /// Each event map is expected to contain:
  /// - `entityType`: one of `sale`, `sale_item`, `product`,
  ///   `credit_customer`, `credit_tx`
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
  static Future<void> updateLastSeen(String deviceId) {
    return supabaseClient.from('devices').upsert({
      'id': deviceId,
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
