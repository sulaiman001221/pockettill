import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Determines whether Supabase is actually reachable, not just whether the
/// device has a network signal.
///
/// Most stores run a hotspot without mobile data, so `connectivity_plus`
/// reporting a connection does not mean the internet - or Supabase - is
/// actually reachable. A network change only triggers a health-check ping;
/// [isReachable] only ever emits `true` once that ping returns `200 OK`.
class ReachabilityService {
  ReachabilityService({required String healthCheckUrl})
    : _healthCheckUri = Uri.parse(healthCheckUrl);

  final Uri _healthCheckUri;
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Emits `true` only after a confirmed 200 OK from the Supabase health
  /// endpoint; emits `false` when there is no network signal or the ping
  /// fails.
  Stream<bool> get isReachable => _controller.stream;

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
      _controller.add(false);
      return;
    }
    unawaited(_pingHealthEndpoint());
  }

  Future<void> _pingHealthEndpoint() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(_healthCheckUri);
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await response.drain<void>();
      _controller.add(response.statusCode == 200);
    } catch (_) {
      _controller.add(false);
    } finally {
      client.close(force: true);
    }
  }

  /// Releases the connectivity subscription and closes [isReachable].
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _controller.close();
  }
}
