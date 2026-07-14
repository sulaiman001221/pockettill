import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/repositories.dart';
import '../../shared/repositories/store_config_repository.dart';
import '../../shared/theme/app_theme.dart';
import 'reachability_service.dart';

/// At-a-glance sync health, shown as a coloured dot across the drawer,
/// Settings, and the Sales screen's sync nudges.
enum SyncIndicatorStatus { synced, pending, overdue, offline, never }

/// Maps [status] to its display colour and label. [lastSyncedAt] is only
/// needed for [SyncIndicatorStatus.overdue]'s "X hours/days" text - pass
/// [SyncStatusNotifier.lastSyncedAt] alongside the watched status.
(Color, String) syncIndicatorDisplay(
  SyncIndicatorStatus status, {
  DateTime? lastSyncedAt,
}) {
  switch (status) {
    case SyncIndicatorStatus.synced:
      return (AppTheme.syncGreen, 'Synced');
    case SyncIndicatorStatus.pending:
      return (AppTheme.syncAmber, 'Sync pending');
    case SyncIndicatorStatus.overdue:
      return (AppTheme.logoutRed, _overdueLabel(lastSyncedAt));
    case SyncIndicatorStatus.offline:
      return (AppTheme.syncGrey, 'No internet');
    case SyncIndicatorStatus.never:
      return (AppTheme.syncGrey, 'Not yet synced');
  }
}

String _overdueLabel(DateTime? lastSyncedAt) {
  if (lastSyncedAt == null) return 'Not synced in a while';
  final elapsed = DateTime.now().difference(lastSyncedAt);
  if (elapsed.inDays >= 1) {
    final days = elapsed.inDays;
    return 'Not synced in $days day${days == 1 ? '' : 's'}';
  }
  final hours = elapsed.inHours;
  return 'Not synced in $hours hour${hours == 1 ? '' : 's'}';
}

/// Derives [SyncIndicatorStatus] from [ReachabilityService] and
/// [StoreConfig.lastSyncedAt] - recomputed on every reachability change and
/// every 60 seconds (so the time-based buckets stay current even with no
/// other trigger).
class SyncStatusNotifier extends StateNotifier<SyncIndicatorStatus> {
  SyncStatusNotifier({
    required StoreConfigRepository storeConfigRepository,
    required ReachabilityService reachabilityService,
  }) : _storeConfigRepository = storeConfigRepository,
       _reachabilityService = reachabilityService,
       super(SyncIndicatorStatus.never) {
    _reachabilitySubscription = _reachabilityService.isReachable.listen(
      (_) => _recompute(),
    );
    _pollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _recompute(),
    );
    _initialLoad = _recompute();
  }

  final StoreConfigRepository _storeConfigRepository;
  final ReachabilityService _reachabilityService;
  StreamSubscription<bool>? _reachabilitySubscription;
  Timer? _pollTimer;
  Future<void>? _initialLoad;

  DateTime? _lastSyncedAt;

  /// The raw last-synced timestamp behind the current status - kept
  /// alongside the enum state (rather than folded into it) since the state
  /// type is just the enum, per how every consumer reads it.
  DateTime? get lastSyncedAt => _lastSyncedAt;

  /// Resolves once the first status computation has completed. Sales
  /// screen's one-time-per-session sync warning awaits this before deciding
  /// whether to show, so it never fires off the notifier's initial
  /// placeholder state before real data has loaded.
  Future<void> ensureLoaded() => _initialLoad ?? _recompute();

  /// Forces an immediate recomputation - e.g. right after a manual "Sync
  /// Now" completes.
  Future<void> refresh() => _recompute();

  Future<void> _recompute() async {
    if (!_reachabilityService.currentlyReachable) {
      _lastSyncedAt = (await _storeConfigRepository.get())?.lastSyncedAt;
      if (mounted) state = SyncIndicatorStatus.offline;
      return;
    }

    final config = await _storeConfigRepository.get();
    _lastSyncedAt = config?.lastSyncedAt;

    if (_lastSyncedAt == null) {
      if (mounted) state = SyncIndicatorStatus.never;
      return;
    }

    final elapsed = DateTime.now().difference(_lastSyncedAt!);
    if (!mounted) return;
    if (elapsed < const Duration(hours: 1)) {
      state = SyncIndicatorStatus.synced;
    } else if (elapsed < const Duration(hours: 24)) {
      state = SyncIndicatorStatus.pending;
    } else {
      state = SyncIndicatorStatus.overdue;
    }
  }

  @override
  void dispose() {
    _reachabilitySubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}

/// Singleton [SyncStatusNotifier] for the app's sync indicator.
final syncStatusProvider =
    StateNotifierProvider<SyncStatusNotifier, SyncIndicatorStatus>((ref) {
      return SyncStatusNotifier(
        storeConfigRepository: ref.watch(storeConfigRepositoryProvider),
        reachabilityService: ref.watch(reachabilityServiceProvider),
      );
    });
