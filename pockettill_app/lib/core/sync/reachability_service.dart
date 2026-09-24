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

  /// While reachability reads false but the device still has a network
  /// signal, re-check this often instead of waiting out the full
  /// [_pingInterval] - a cashier looking at "No internet" for up to 30s (the
  /// old worst case) after a blip that already cleared is the reported
  /// symptom ("shows no internet, then syncs after a few seconds or a
  /// minute", 2026-09-24). One tiny GET every few seconds, only while
  /// offline with a signal, is a cheap price for recovering fast.
  static const _recoveryInterval = Duration(seconds: 5);

  /// Per-attempt limit for the health-check request (connect, then
  /// response). 5s was too tight for a weak hotspot/mobile link, where a
  /// cold TLS handshake alone can exceed it - two of those back to back
  /// read as "offline" even though the connection was merely slow.
  static const _pingTimeout = Duration(seconds: 8);

  /// How long a "no network signal" report must persist before it's
  /// believed. Android routinely reports a momentary `none` while it
  /// re-evaluates or switches networks (wifi <-> mobile data); acting on it
  /// instantly flashed "No internet" and tore down the live connection for
  /// a blip that was already over.
  static const _offlineDebounce = Duration(seconds: 3);

  final Uri _healthCheckUri;
  final String _apiKey;
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pingTimer;
  Timer? _recoveryTimer;
  Timer? _offlineDebounceTimer;
  Future<void>? _pingInFlight;
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
      // Don't believe a "no signal" report until it's held for a moment -
      // see [_offlineDebounce]. If signal returns before then, the branch
      // below cancels this.
      _offlineDebounceTimer ??= Timer(_offlineDebounce, () async {
        _offlineDebounceTimer = null;
        final again = await _connectivity.checkConnectivity();
        if (again.any((result) => result != ConnectivityResult.none)) {
          _handleConnectivityChanged(again);
          return;
        }
        _pingTimer?.cancel();
        _pingTimer = null;
        _setReachable(false);
      });
      return;
    }

    _offlineDebounceTimer?.cancel();
    _offlineDebounceTimer = null;
    unawaited(_pingHealthEndpoint());
    _pingTimer ??= Timer.periodic(
      _pingInterval,
      (_) => unawaited(_pingHealthEndpoint()),
    );
  }

  /// Something other than the health ping just proved Supabase is
  /// reachable - a sync cycle that completed, for instance. Clears a stale
  /// "offline" reading immediately instead of leaving it up until the next
  /// ping happens to succeed. Does nothing (and emits nothing) if already
  /// reachable, so a steady stream of successful syncs isn't a steady stream
  /// of reachability events.
  void confirmReachable() {
    if (_currentlyReachable) return;
    _setReachable(true);
  }

  /// A single failed ping is often just a transient blip - a dropped
  /// packet, a momentary DNS hiccup, switching between wifi and mobile
  /// data - rather than a real outage, and this is the app's *only*
  /// signal for "no internet" shown directly to a cashier mid-sale. One
  /// retry after a short pause avoids flashing that warning (and the sync
  /// indicator alongside it) for something that clears itself a second
  /// later; a second consecutive failure is treated as a real drop. Found
  /// 2026-08-23 from exactly that flicker being reported - reachability
  /// and sync recovered fine on their own moments later every time.
  ///
  /// Only one check runs at a time: with the faster [_recoveryInterval]
  /// re-check a slow ping could otherwise still be running when the next
  /// one starts, and two overlapping checks racing to report opposite
  /// results is its own source of flicker. A caller arriving mid-check just
  /// waits for that one.
  Future<void> _pingHealthEndpoint() {
    return _pingInFlight ??= _runPing().whenComplete(() => _pingInFlight = null);
  }

  Future<void> _runPing() async {
    if (await _attemptPing()) {
      _setReachable(true);
      return;
    }
    await Future.delayed(const Duration(seconds: 2));
    _setReachable(await _attemptPing());
  }

  Future<bool> _attemptPing() async {
    final client = HttpClient()..connectionTimeout = _pingTimeout;
    try {
      final request = await client.getUrl(_healthCheckUri);
      request.headers.set('apikey', _apiKey);
      final response = await request.close().timeout(_pingTimeout);
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void _setReachable(bool reachable) {
    _currentlyReachable = reachable;
    _controller.add(reachable);

    if (reachable) {
      _recoveryTimer?.cancel();
      _recoveryTimer = null;
    } else if (_pingTimer != null) {
      // Offline but still holding a network signal (a real signal loss
      // cancels [_pingTimer]) - the likely case is a blip, so re-check soon
      // rather than after the full periodic interval.
      _recoveryTimer ??= Timer.periodic(
        _recoveryInterval,
        (_) => unawaited(_pingHealthEndpoint()),
      );
    }
  }

  /// Releases the connectivity subscription and closes [isReachable].
  Future<void> dispose() async {
    _pingTimer?.cancel();
    _recoveryTimer?.cancel();
    _offlineDebounceTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _controller.close();
  }
}

/// The app-wide [ReachabilityService] singleton, constructed and
/// initialized once in main() and injected via [ProviderScope] overrides.
final reachabilityServiceProvider = Provider<ReachabilityService>((ref) {
  throw UnimplementedError('reachabilityServiceProvider must be overridden.');
});
