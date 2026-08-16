import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Determines whether Supabase is actually reachable, not just whether the
/// device has a network signal.
///
/// Most stores run a hotspot without mobile data, so `connectivity_plus`
/// reporting a connection does not mean the internet - or Supabase - is
/// actually reachable. A network change only triggers a health-check ping to
/// `{SUPABASE_URL}/auth/v1/health`; [isReachable] only ever emits `true` once
/// that ping returns `200 OK`. While network is present, the ping repeats
/// every 30 seconds; it stops entirely when the network drops.
///
/// The health check hits `/auth/v1/health` rather than the bare `/rest/v1/`
/// root: newer Supabase projects issue `sb_publishable_...`-format API keys,
/// and those keys get a `401 "Secret API key required"` from the `/rest/v1/`
/// root/spec route specifically (real table queries under `/rest/v1/<table>`
/// work fine with them) - so `/rest/v1/` never reported reachable even with
/// a valid key and working internet.
class ReachabilityService {
  ReachabilityService({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) : _healthCheckUri = Uri.parse('$supabaseUrl/auth/v1/health'),
       _apiKey = supabaseAnonKey;

  static const _pingInterval = Duration(seconds: 30);

  final Uri _healthCheckUri;
  final String _apiKey;
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pingTimer;
  bool _currentlyReachable = false;

  /// Emits `true` only after a confirmed 200 OK from the Supabase health
  /// endpoint; emits `false` when there is no network signal or the ping
  /// fails.
  Stream<bool> get isReachable => _controller.stream;

  /// The most recently determined reachability state.
  bool get currentlyReachable => _currentlyReachable;

  /// Confirms reachability before a caller spends something scarce (an OTP
  /// send, a registration attempt) on the strength of "are we online" and
  /// can't afford a false negative. [currentlyReachable] alone isn't safe
  /// for that: it's only as fresh as the last periodic ping (up to
  /// [_pingInterval] old), or still the cold-start default `false` if no
  /// ping has completed yet - checking it right when a screen opens can
  /// false-positive as offline with a perfectly good connection. When it
  /// already reads true, that's trusted as-is (no need to pay for another
  /// ping just to confirm good news); when it reads false, this runs one
  /// fresh check before believing it.
  Future<bool> ensureReachable() async {
    if (_currentlyReachable) return true;
    await _pingHealthEndpoint();
    return _currentlyReachable;
  }

  /// Starts listening for connectivity changes and runs an initial check.
  Future<void> init() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChanged,
    );
    _handleConnectivityChanged(await _connectivity.checkConnectivity());
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final hasNetworkSignal = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (!hasNetworkSignal) {
      _pingTimer?.cancel();
      _pingTimer = null;
      _setReachable(false);
      return;
    }

    unawaited(_pingHealthEndpoint());
    _pingTimer ??= Timer.periodic(
      _pingInterval,
      (_) => unawaited(_pingHealthEndpoint()),
    );
  }

  Future<void> _pingHealthEndpoint() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(_healthCheckUri);
      request.headers.set('apikey', _apiKey);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await response.drain<void>();
      _setReachable(response.statusCode == 200);
    } catch (_) {
      _setReachable(false);
    } finally {
      client.close(force: true);
    }
  }

  void _setReachable(bool reachable) {
    _currentlyReachable = reachable;
    _controller.add(reachable);
  }

  /// Releases the connectivity subscription and closes [isReachable].
  Future<void> dispose() async {
    _pingTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _controller.close();
  }
}

/// The app-wide [ReachabilityService] singleton, constructed and
/// initialized once in main() and injected via [ProviderScope] overrides.
final reachabilityServiceProvider = Provider<ReachabilityService>((ref) {
  throw UnimplementedError('reachabilityServiceProvider must be overridden.');
});
