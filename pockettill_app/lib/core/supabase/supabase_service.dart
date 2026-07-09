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
  /// - `entityType`: one of `sale`, `product`, `credit_customer`, `credit_tx`
  /// - `operation`: `create`, `update`, or `delete`
  /// - `entityUuid`: the row's primary key
  /// - `payload`: the decoded row data (used for `create`/`update`)
  ///
  /// Events are grouped by their destination table so each table only needs
  /// a single upsert/delete call per batch.
  static Future<void> pushEvents(List<Map<String, dynamic>> events) async {
    final upsertsByTable = <String, List<Map<String, dynamic>>>{};
    final deletesByTable = <String, List<String>>{};

    for (final event in events) {
      final table = _entityTables[event['entityType']];
      if (table == null) continue;

      if (event['operation'] == 'delete') {
        (deletesByTable[table] ??= []).add(event['entityUuid'] as String);
      } else {
        final payload = Map<String, dynamic>.from(
          event['payload'] as Map<Object?, Object?>,
        );
        (upsertsByTable[table] ??= []).add(payload);
      }
    }

    for (final entry in upsertsByTable.entries) {
      await supabaseClient.from(entry.key).upsert(entry.value);
    }
    for (final entry in deletesByTable.entries) {
      await supabaseClient.from(entry.key).delete().inFilter('id', entry.value);
    }
  }

  /// Marks a device as having just synced.
  static Future<void> updateLastSeen(String deviceId) {
    return supabaseClient
        .from('devices')
        .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', deviceId);
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
