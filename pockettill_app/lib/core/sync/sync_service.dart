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
  'product',
  'credit_customer',
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

      final pending = await _eventQueue.getPending();

      if (pending.isEmpty) {
        await _pullCatalogueUpdates(storeConfig.lastSyncedAt);
        _statusController.add(SyncStatus.success);
        return;
      }

      final eventsByType = <String, List<SyncEvent>>{};
      for (final event in pending) {
        (eventsByType[event.entityType] ??= []).add(event);
      }

      for (final entityType in _entityTypePriority) {
        final events = eventsByType[entityType];
        if (events == null || events.isEmpty) continue;

        for (var offset = 0; offset < events.length; offset += _batchSize) {
          final batch = events.skip(offset).take(_batchSize).toList();
          await SupabaseService.pushEvents(batch.map(_toEventMap).toList());
          await _eventQueue.markPushed(
            batch.map((event) => event.uuid).toList(),
          );
        }
      }

      final pulledCount = await _pullCatalogueUpdates(storeConfig.lastSyncedAt);

      final now = DateTime.now();
      await _isar.writeTxn(() async {
        storeConfig.lastSyncedAt = now;
        await _isar.storeConfigs.put(storeConfig);
      });

      await SupabaseService.updateLastSeen(storeConfig.deviceId);

      await SupabaseService.supabaseClient.from('sync_log').insert({
        'device_id': storeConfig.deviceId,
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

  Map<String, dynamic> _toEventMap(SyncEvent event) {
    return {
      'entityType': event.entityType,
      'operation': event.operation,
      'entityUuid': event.entityUuid,
      'payload': jsonDecode(event.payload),
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
