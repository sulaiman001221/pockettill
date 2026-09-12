import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../shared/models/store_config.dart';
import '../../shared/models/sync_event.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/repositories/risk_log_repository.dart';
import '../../shared/utils/sync_status.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';
import 'event_queue.dart';
import 'image_sync_service.dart';

/// Priority order [SyncEvent]s are pushed in - highest priority first.
///
/// `product` must come before `stock_event`: `stock_events.product_id` has
/// a foreign-key constraint against `products`, so a brand-new product's
/// `initial_stock` event (queued alongside its own `product` create event)
/// would otherwise try to insert before the product it references exists
/// remotely. That single failure aborts the whole push loop for *every*
/// entity type after it - not a transient error, a permanent deadlock,
/// since the same product event never gets a turn to push and fix it.
/// Found 2026-09-10 - a real device stuck retrying this exact failure for
/// hours, blocked from syncing (or even logging out) at all.
const List<String> _entityTypePriority = [
  'product',
  'credit_tx',
  'sale',
  'sale_item',
  'stock_event',
  'extra_income',
  'return',
  'return_item',
  'credit_customer',
  'store_profile',
  'risk_log',
];

const int _batchSize = 50;

/// Drains the local [EventQueue] to Supabase in priority order, then pulls
/// shared-catalogue updates. Call [sync] whenever [ReachabilityService]
/// confirms connectivity - never on network signal alone.
class SyncService {
  SyncService({
    required Isar isar,
    required EventQueue eventQueue,
    ImageSyncService? imageSync,
    RiskLogRepository? riskLog,
  }) : _isar = isar,
       _eventQueue = eventQueue,
       _imageSync = imageSync,
       _riskLog = riskLog;

  final Isar _isar;
  final EventQueue _eventQueue;

  // Nullable - the app-wide singleton (via syncServiceProvider) always
  // supplies one, but a couple of call sites (AuthService.logout's
  // just-flush-pending-events push) build a bare SyncService by hand
  // outside the normal provider graph and have no need to also wire up a
  // ProductRepository just to satisfy this - image syncing is skipped
  // entirely for those, which is fine since it's fire-and-forget anyway.
  final ImageSyncService? _imageSync;

  // Nullable for the same reason as [_imageSync] above - only used for
  // concurrent-edit detection (see _detectProductConflicts), never for
  // anything the bare-constructed logout() flush needs.
  final RiskLogRepository? _riskLog;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  final StreamController<void> _displacedController =
      StreamController<void>.broadcast();

  bool _isSyncing = false;

  /// Emits the current phase of the sync cycle.
  Stream<SyncStatus> get syncStatus => _statusController.stream;

  /// Emits once this device has been remotely logged out - the owner tapped
  /// "Log out this device" for it in Settings > Active Devices (clears this
  /// device's `devices.verified_at`).
  ///
  /// Used to feed a forced single-active-device logout on every new login
  /// until 2026-09-09 - removed since it didn't prevent the real problem
  /// (two devices working offline simultaneously, neither yet revoked) and
  /// stock is event-sourced now anyway (see stock_events). This needs its
  /// own signal for the same reason the old mechanism did: a JWT is
  /// verified by signature, not looked up, so a revoked device keeps
  /// working - and keeps syncing - until its access token naturally expires
  /// up to an hour later. Sync is the app's regular check-in with the
  /// server, so it's also where a remote logout gets noticed promptly.
  Stream<void> get displacedByAnotherDevice => _displacedController.stream;

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
      if (!storeConfig.isLoggedIn) {
        // Logged out, but still fully configured locally - logout()
        // deliberately keeps storeId/products/sales/etc. around so the app
        // keeps working offline, so storeId.isEmpty above doesn't catch
        // this case. Without this check, a background sync (triggered by
        // ReachabilityService on every reconnect, independent of any
        // screen being open) kept retrying with no valid session and
        // failing every single push with 401 - looking exactly like sync
        // "stuck pending" forever, since the same events never got marked
        // pushed. Found 2026-08-22.
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

          // Checked before pushing, not after: once this device's own
          // upsert lands, the remote row's updated_at becomes *this*
          // device's edit, so there'd be nothing left to compare against.
          if (entityType == 'product') {
            await _detectProductConflicts(events, storeId);
          }

          try {
            for (
              var offset = 0;
              offset < events.length;
              offset += _batchSize
            ) {
              final batch = events.skip(offset).take(_batchSize).toList();
              await SupabaseService.pushEvents(
                batch.map((event) => _toEventMap(event, storeId)).toList(),
              );
              await _eventQueue.markPushed(
                batch.map((event) => event.uuid).toList(),
              );
            }
          } catch (e, st) {
            // One entity type failing to push (a genuine data problem, or
            // just a transient error) must not block every other type
            // queued after it, or the heartbeat/catalogue-pull/revoked
            // check below - that's exactly what turned one bad
            // stock_event into a total, permanent sync deadlock (see the
            // entity-order comment above). Its events stay pending and
            // retry on the next cycle; every other type still gets its
            // turn this cycle.
            debugPrint(
              'SyncService.sync(): push failed for $entityType: $e\n$st',
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

      // Fire-and-forget, deliberately not awaited: image syncing is lower
      // priority than the data sync above and must never delay it or make
      // it wait on a slow/failed image download - see ImageSyncService.
      final imageSync = _imageSync;
      if (imageSync != null) unawaited(imageSync.syncStoreImages());

      // Deliberately last, after everything above has pushed: this device's
      // access token is still valid until it expires, so a revoked device
      // can still upload the sales it recorded before being revoked -
      // signing it out first would strand them locally until the owner
      // logged back in on this device.
      if (storeConfig.isLoggedIn) {
        final revoked = await SupabaseService.isThisDeviceRevoked(
          storeId: storeId,
          deviceId: storeConfig.deviceId,
        );
        if (revoked) _displacedController.add(null);
      }
    } catch (e, st) {
      // Was a silent `catch (_)` - a sync failure had genuinely no trace
      // anywhere (not in the app, not in Supabase), so "sync gets stuck on
      // pending" reports had nothing to diagnose from. debugPrint is
      // stripped in release builds but shows up in a debug build's logcat,
      // which is what actually matters here.
      debugPrint('SyncService.sync() failed: $e\n$st');
      _statusController.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Best-effort visibility for the "last write wins" conflict resolution
  /// products already get for free from a plain Postgres upsert - this
  /// doesn't change what happens to the data (the push below still
  /// proceeds and still wins), it just logs to risk_log when it detects
  /// that this device's edit and another device's edit to the *same*
  /// product's *metadata* (name, price, category) genuinely raced.
  ///
  /// Deliberately never compares stock: stock is event-sourced (see
  /// stock_events in SCHEMA_TRUTH.md) - two devices selling the same
  /// product offline is the normal, expected case the whole delta model
  /// exists to handle correctly, not a conflict. The old version of this
  /// check compared the payload's `stock` against the remote column and
  /// logged "concurrent stock edit" for completely ordinary, unrelated
  /// sales on two devices (the remote `stock` column is never live-updated
  /// by a sale in the first place, so it almost always differed from
  /// whatever this device's own running total happened to be, regardless
  /// of whether anything actually conflicted) - a real, repeatedly-firing
  /// false positive found 2026-09-12 on a real two-device store. Only a
  /// genuine metadata edit (a manual product edit, the one path that
  /// pushes a `product` event at all) can reach this method, so removing
  /// stock from the comparison doesn't lose real conflict detection - it
  /// was never a valid signal for one.
  ///
  /// A single batched read, not one query per event: for every pending
  /// [events] with a [SyncEvent.baseUpdatedAt] (i.e. an edit to an
  /// *existing* product, not a brand-new one - see ProductRepository.save),
  /// compares the remote row's *current* updated_at against that baseline.
  /// If the remote value has moved past it, some other device's edit must
  /// have reached the server after this device's edit was made (this
  /// device can't have caused that itself - it hasn't pushed since) - a
  /// genuine concurrent edit, not just this device re-syncing its own
  /// earlier change.
  Future<void> _detectProductConflicts(
    List<SyncEvent> events,
    String storeId,
  ) async {
    final riskLog = _riskLog;
    if (riskLog == null) return;

    final withBase = events.where((e) => e.baseUpdatedAt != null).toList();
    if (withBase.isEmpty) return;

    try {
      final uuids = withBase.map((e) => e.entityUuid).toSet().toList();
      final rows = await SupabaseService.supabaseClient
          .from('products')
          .select('uuid, updated_at, price, name, category')
          .inFilter('uuid', uuids)
          .eq('store_id', storeId);
      final remoteByUuid = {
        for (final row in rows) row['uuid'] as String: row,
      };

      for (final event in withBase) {
        final remote = remoteByUuid[event.entityUuid];
        final remoteUpdatedAt = remote?['updated_at'] as String?;
        if (remote == null || remoteUpdatedAt == null) continue;
        if (!DateTime.parse(
          remoteUpdatedAt,
        ).isAfter(DateTime.parse(event.baseUpdatedAt!))) {
          continue;
        }

        final payload = jsonDecode(event.payload) as Map<String, dynamic>;
        final name =
            payload['name'] as String? ?? remote['name'] as String? ?? 'Product';
        final localPrice = (payload['price'] as num?)?.toDouble();
        final remotePrice = (remote['price'] as num?)?.toDouble();

        if (localPrice != null &&
            remotePrice != null &&
            localPrice != remotePrice) {
          await riskLog.record(
            type: 'concurrent_price_edit',
            description: 'Price edited on two devices at the same time for $name',
            beforeValue: 'R${remotePrice.toStringAsFixed(2)}',
            afterValue: 'R${localPrice.toStringAsFixed(2)}',
            entityName: name,
          );
          continue;
        }

        final localName = payload['name'] as String?;
        final localCategory = payload['category'] as String?;
        final remoteName = remote['name'] as String?;
        final remoteCategory = remote['category'] as String?;
        final nameChanged = localName != null && localName != remoteName;
        final categoryChanged =
            localCategory != remoteCategory && (localCategory != null || remoteCategory != null);

        if (nameChanged) {
          await riskLog.record(
            type: 'concurrent_product_edit',
            description:
                'Details edited on two devices at the same time for $name',
            beforeValue: remoteName ?? '',
            afterValue: localName,
            entityName: name,
          );
        } else if (categoryChanged) {
          await riskLog.record(
            type: 'concurrent_product_edit',
            description:
                'Details edited on two devices at the same time for $name',
            beforeValue: remoteCategory ?? '',
            afterValue: localCategory ?? '',
            entityName: name,
          );
        }
      }
    } catch (_) {
      // Best-effort - a failed conflict check must never block the actual
      // push, and there's nothing a caller could usefully do about it.
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

/// The app-wide [ImageSyncService] singleton - its own provider (rather than
/// built inline inside [syncServiceProvider]) so [lowStorageWarningProvider]
/// below can watch the exact same instance [SyncService] drives.
final imageSyncServiceProvider = Provider<ImageSyncService>((ref) {
  return ImageSyncService(
    isar: ref.watch(isarProvider),
    productRepository: ref.watch(productRepositoryProvider),
  );
});

/// The app-wide [SyncService] singleton.
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    isar: ref.watch(isarProvider),
    eventQueue: EventQueue(ref.watch(isarProvider)),
    imageSync: ref.watch(imageSyncServiceProvider),
    riskLog: ref.watch(riskLogRepositoryProvider),
  );
});

/// True while product-image downloads are paused for low device storage -
/// see [ImageSyncService.lowStorageWarning]. Watched by SalesScreen for a
/// one-time warning banner that clears itself once storage recovers.
final lowStorageWarningProvider = StreamProvider<bool>((ref) {
  return ref.watch(imageSyncServiceProvider).lowStorageWarning;
});

/// The current phase of [SyncService]'s sync cycle, for UI that needs to
/// show a "syncing" state regardless of what triggered the sync (a manual
/// "Sync Now" tap, or the background reachability-triggered sync in main()).
final syncCycleStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.watch(syncServiceProvider).syncStatus;
});
