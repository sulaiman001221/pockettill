import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../shared/models/store_config.dart';
import '../../shared/models/sync_event.dart';
import '../../shared/utils/sync_status.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';
import 'event_queue.dart';

/// Priority order [SyncEvent]s are pushed in - highest priority first.
const List<String> _entityTypePriority = [
  'credit_tx',
  'sale',
  'sale_item',
  'extra_income',
  'return',
  'return_item',
  'product',
  'credit_customer',
  'store_profile',
];

const int _batchSize = 50;

/// Drains the local [EventQueue] to Supabase in priority order, then pulls
/// shared-catalogue updates. Call [sync] whenever [ReachabilityService]
/// confirms connectivity - never on network signal alone.
class SyncService {
  SyncService({required Isar isar, required EventQueue eventQueue})
    : _isar = isar,
      _eventQueue = eventQueue;

  final Isar _isar;
  final EventQueue _eventQueue;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  bool _isSyncing = false;

  /// Emits the current phase of the sync cycle.
  Stream<SyncStatus> get syncStatus => _statusController.stream;

  /// Runs one full sync cycle: push pending events, then pull catalogue
  /// updates. A no-op if a cycle is already in progress.
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _statusController.add(SyncStatus.syncing);

    try {
      final storeConfig = await _isar.storeConfigs.get(1);
      if (storeConfig == null) {
        // No store provisioned yet - nothing to sync against.
        _statusController.add(SyncStatus.idle);
        return;
      }
      if (storeConfig.storeId.isEmpty) {
        // Pre-auth state: a StoreConfig exists locally (e.g. an eagerly
        // created placeholder) but hasn't been through registration/login
        // yet, so there's no real store to attach rows to in Supabase.
        _statusController.add(SyncStatus.idle);
        return;
      }
      final storeId = storeConfig.storeId;

      final pending = await _eventQueue.getPending();

      if (pending.isNotEmpty) {
        final eventsByType = <String, List<SyncEvent>>{};
        for (final event in pending) {
          (eventsByType[event.entityType] ??= []).add(event);
        }

        for (final entityType in _entityTypePriority) {
          final events = eventsByType[entityType];
          if (events == null || events.isEmpty) continue;

          for (var offset = 0; offset < events.length; offset += _batchSize) {
            final batch = events.skip(offset).take(_batchSize).toList();
            await SupabaseService.pushEvents(
              batch.map((event) => _toEventMap(event, storeId)).toList(),
            );
            await _eventQueue.markPushed(
              batch.map((event) => event.uuid).toList(),
            );
          }
        }
      }

      final pulledCount = await _pullCatalogueUpdates(storeConfig.lastSyncedAt);

      final now = DateTime.now();
      await _isar.writeTxn(() async {
        storeConfig.lastSyncedAt = now;
        await _isar.storeConfigs.put(storeConfig);
      });

      await SupabaseService.updateLastSeen(storeConfig.deviceId, storeId);

      await SupabaseService.supabaseClient.from('sync_log').insert({
        'device_id': storeConfig.deviceId,
        'store_id': storeId,
        'events_pushed': pending.length,
        'events_pulled': pulledCount,
      });

      _statusController.add(SyncStatus.success);
    } catch (_) {
      _statusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Pulls verified catalogue products created since [since]. Returns how
  /// many rows were pulled. Writing the pulled rows into local Isar Product
  /// records is out of scope for this stage - that lands with the
  /// repository layer.
  Future<int> _pullCatalogueUpdates(DateTime? since) async {
    final rows = await SupabaseService.pullCatalogueUpdates(
      since ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
    return rows.length;
  }

  Map<String, dynamic> _toEventMap(SyncEvent event, String storeId) {
    final payload = Map<String, dynamic>.from(
      jsonDecode(event.payload) as Map,
    );
    // store_profile rows in the `stores` table are the store, so they don't
    // get a store_id column - every other entity attaches to one.
    if (event.operation != 'delete' && event.entityType != 'store_profile') {
      payload['store_id'] = storeId;
    }
    return {
      'entityType': event.entityType,
      'operation': event.operation,
      'entityUuid': event.entityUuid,
      'payload': payload,
    };
  }

  /// Closes the [syncStatus] stream.
  Future<void> dispose() async {
    await _statusController.close();
  }
}

/// The app-wide [SyncService] singleton.
final syncServiceProvider = Provider<SyncService>((ref) {
  final isar = ref.watch(isarProvider);
  return SyncService(isar: isar, eventQueue: EventQueue(isar));
});

/// The current phase of [SyncService]'s sync cycle, for UI that needs to
/// show a "syncing" state regardless of what triggered the sync (a manual
/// "Sync Now" tap, or the background reachability-triggered sync in main()).
final syncCycleStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncServiceProvider).syncStatus;
});
