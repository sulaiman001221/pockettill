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
  static SupabaseClient get client => Supabase.instance.client;
}
