import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/store_config.dart';
import '../../shared/models/sync_event.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/repositories/risk_log_repository.dart';
import '../../shared/utils/sync_status.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';
import 'event_queue.dart';
import 'image_sync_service.dart';
import 'server_row_applier.dart';
import 'sync_coordinator.dart';

/// Priority order [SyncEvent]s are pushed in - highest priority first.
///
/// `product` must come before `stock_event`: `stock_events.product_id` has a
/// foreign-key constraint against `products`, so a brand-new product's
/// `initial_stock` event (queued alongside its own `product` create event)
/// would otherwise try to insert before the product it references exists
/// remotely.
const List<String> _entityTypePriority = [
  'product',
  'credit_customer',
  'credit_tx',
  'sale',
  'sale_item',
  'stock_event',
  'extra_income',
  'return',
  'return_item',
  'store_profile',
  'risk_log',
];

const int _batchSize = 50;

/// Postgres foreign-key violation - see [SyncService._pushStockEvents].
const String _foreignKeyViolation = '23503';

/// Drains the local [EventQueue] to Supabase in priority order, then pulls
/// shared-catalogue updates. Call [sync] whenever [ReachabilityService]
/// confirms connectivity - never on network signal alone.
///
/// What each kind of local change turns into on the server:
///
/// - **Ledger facts** - a sale, return, restock, credit purchase, repayment,
///   manual credit or write-off - are plain inserts. The database applies
///   them to the product's stock or the customer's balance itself (see the
///   triggers in SCHEMA_TRUTH.md), so two devices recording facts at the same
///   time always both count.
/// - **A person editing a form** (product details/stock, customer
///   details) goes through an atomic `apply_*_edit` function that checks
///   nobody else changed the same field since this device started editing.
///   A losing edit is not applied, is recorded in the Risk Log, and the
///   device shows the server's value instead.
/// - **Background image changes** are a plain single-column update, never
///   part of that conflict check.
class SyncService {
  SyncService({
    required Isar isar,
    required EventQueue eventQueue,
    ImageSyncService? imageSync,
    RiskLogRepository? riskLog,
  }) : _isar = isar,
       _eventQueue = eventQueue,
       _imageSync = imageSync,
       _riskLog = riskLog,
       _applier = ServerRowApplier(isar);

  final Isar _isar;
  final EventQueue _eventQueue;
  final ServerRowApplier _applier;

  // Nullable - the app-wide singleton (via syncServiceProvider) always
  // supplies one, but a couple of call sites (AuthService.logout's
  // just-flush-pending-events push) build a bare SyncService by hand
  // outside the normal provider graph - image syncing is skipped entirely
  // for those, which is fine since it's fire-and-forget anyway.
  final ImageSyncService? _imageSync;

  // Nullable for the same reason - only used to record a rejected edit.
  final RiskLogRepository? _riskLog;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  final StreamController<void> _displacedController =
      StreamController<void>.broadcast();

  bool _isSyncing = false;
  DateTime? _lastImageSync;

  /// Emits the current phase of the sync cycle.
  Stream<SyncStatus> get syncStatus => _statusController.stream;

  /// Emits once this device has been remotely logged out - the owner tapped
  /// "Log out this device" for it in Settings > Active Devices (clears this
  /// device's `devices.verified_at`). A JWT is verified by signature, not
  /// looked up, so a revoked device keeps working until its access token
  /// expires; sync is the app's regular check-in with the server, so it's
  /// where a remote logout gets noticed promptly.
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
        // keeps working offline. Without this check, a background sync
        // kept retrying with no valid session and failing every push with
        // 401 - looking exactly like sync "stuck pending" forever.
        _statusController.add(SyncStatus.idle);
        return;
      }
      final storeId = storeConfig.storeId;

      final pending = await _eventQueue.getPending();

      if (pending.isNotEmpty) {
        SyncCoordinator.pushInFlight = true;
        try {
          final eventsByType = <String, List<SyncEvent>>{};
          for (final event in pending) {
            (eventsByType[event.entityType] ??= []).add(event);
          }

          for (final entityType in _entityTypePriority) {
            final typeEvents = eventsByType[entityType];
            if (typeEvents == null || typeEvents.isEmpty) continue;

            try {
              switch (entityType) {
                case 'product':
                  await _pushProductEvents(typeEvents, storeConfig);
                case 'credit_customer':
                  await _pushCustomerEvents(typeEvents, storeConfig);
                case 'stock_event':
                  await _pushStockEvents(typeEvents, storeId);
                default:
                  await _pushBatched(typeEvents, storeId);
              }
            } catch (e, st) {
              // One entity type failing to push (a genuine data problem, or
              // just a transient error) must not block every other type
              // queued after it, or the heartbeat/catalogue-pull/revoked
              // check below. Its events stay pending and retry on the next
              // cycle; every other type still gets its turn this cycle.
              debugPrint(
                'SyncService.sync(): push failed for $entityType: $e\n$st',
              );
            }
          }
        } finally {
          SyncCoordinator.pushInFlight = false;
        }
      }

      final pulledCount = await _pullCatalogueUpdates(storeConfig.lastSyncedAt);

      final now = DateTime.now();
      await _isar.writeTxn(() async {
        final fresh = await _isar.storeConfigs.get(1);
        if (fresh == null) return;
        fresh.lastSyncedAt = now;
        await _isar.storeConfigs.put(fresh);
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
      // Throttled: a sync now runs whenever something new is queued, and the
      // catalogue image check doesn't need to hit the network every time.
      final imageSync = _imageSync;
      final lastImageSync = _lastImageSync;
      if (imageSync != null &&
          (lastImageSync == null ||
              now.difference(lastImageSync) > const Duration(minutes: 2))) {
        _lastImageSync = now;
        unawaited(imageSync.syncStoreImages());
      }

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
      // anywhere, so "sync gets stuck on pending" reports had nothing to
      // diagnose from. debugPrint is stripped in release builds but shows
      // up in a debug build's logcat, which is what actually matters here.
      debugPrint('SyncService.sync() failed: $e\n$st');
      _statusController.add(SyncStatus.error);
    } finally {
      SyncCoordinator.pushInFlight = false;
      _isSyncing = false;
    }
  }

  // -- plain pushes ---------------------------------------------------------

  /// Pushes [events] as upserts/deletes, [_batchSize] at a time, marking each
  /// batch pushed once it lands.
  Future<void> _pushBatched(List<SyncEvent> events, String storeId) async {
    for (var offset = 0; offset < events.length; offset += _batchSize) {
      final batch = events.skip(offset).take(_batchSize).toList();
      await SupabaseService.pushEvents(
        batch.map((event) => _toEventMap(event, storeId)).toList(),
      );
      await _eventQueue.markPushed(batch.map((event) => event.uuid).toList());
    }
  }

  /// A stock event whose product no longer exists on the server (deleted
  /// elsewhere, or deleted here before the event was sent) fails its foreign
  /// key forever. Left alone, that one event blocks every stock event queued
  /// behind it - and the logout check that waits for an empty queue - so it
  /// is found by retrying one at a time and dropped.
  Future<void> _pushStockEvents(List<SyncEvent> events, String storeId) async {
    try {
      await _pushBatched(events, storeId);
      return;
    } on PostgrestException catch (e) {
      if (e.code != _foreignKeyViolation) rethrow;
    }
    for (final event in events) {
      try {
        await _pushBatched([event], storeId);
      } on PostgrestException catch (e) {
        if (e.code != _foreignKeyViolation) rethrow;
        await _eventQueue.discard([event.uuid]);
      }
    }
  }

  // -- products -------------------------------------------------------------

  Future<void> _pushProductEvents(
    List<SyncEvent> events,
    StoreConfig config,
  ) async {
    final storeId = config.storeId;
    final run = <SyncEvent>[];

    Future<void> flush() async {
      if (run.isEmpty) return;
      await _pushBatched(List.of(run), storeId);
      run.clear();
    }

    // Oldest first, and a row's events must land in the order they were
    // made (create, then edits, then delete) - so anything that isn't a plain
    // create/delete first flushes the run of plain ones queued before it.
    for (final event in events) {
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      if (event.operation == 'image_update') {
        await flush();
        await SupabaseService.supabaseClient
            .from('products')
            .update({'image_url': payload['image_url']})
            .eq('uuid', event.entityUuid)
            .eq('store_id', storeId);
        await _eventQueue.markPushed([event.uuid]);
      } else if (event.operation == 'update') {
        await flush();
        final edit = payload['_edit'] as Map<String, dynamic>?;
        if (edit != null) {
          await _pushProductEdit(event, edit, config);
        } else {
          await _pushLegacyProductUpdate(event, payload, storeId);
        }
      } else {
        run.add(event);
      }
    }
    await flush();
  }

  Future<void> _pushProductEdit(
    SyncEvent event,
    Map<String, dynamic> edit,
    StoreConfig config,
  ) async {
    final result = await SupabaseService.supabaseClient.rpc(
      'apply_product_edit',
      params: {
        'p_uuid': event.entityUuid,
        'p_store_id': config.storeId,
        'p_device_id': config.deviceId,
        'p_base': edit['base'],
        'p_changes': edit['changes'],
        'p_base_stock_version': edit['base_stock_version'],
        'p_stock_delta': edit['stock_delta'],
        'p_edit_id': edit['edit_id'],
      },
    );
    final outcome = Map<String, dynamic>.from(result as Map);
    await _eventQueue.markPushed([event.uuid]);

    // Deleted elsewhere - the next pull's reconciliation removes it here.
    if (outcome['found'] != true) return;

    final row = Map<String, dynamic>.from(outcome['row'] as Map);
    // Adopt whatever the server now holds - this device's own edit if it
    // won, the other device's value if it lost.
    await _applier.applyProduct(row);

    final conflicts = List<String>.from(outcome['conflicts'] as List);
    if (conflicts.isEmpty) return;
    final name = row['name'] as String? ?? 'Product';
    final stockConflict = conflicts.contains('stock');
    final otherConflicts = conflicts.where((f) => f != 'stock').toList();
    final riskLog = _riskLog;
    if (riskLog == null) return;
    if (stockConflict) {
      await riskLog.record(
        type: 'concurrent_stock_edit',
        description:
            'Concurrent stock quantity edit on $name - not applied because '
            'another device edited it first. Showing the current quantity.',
        beforeValue: 'Your edit: ${_signed(edit['stock_delta'])}',
        afterValue: 'Now ${(row['stock'] as num).toInt()}',
        entityName: name,
      );
    }
    if (otherConflicts.isNotEmpty) {
      await riskLog.record(
        type: 'concurrent_product_edit',
        description:
            'Concurrent edit on $name - your change to '
            '${otherConflicts.join(', ')} was not applied because another '
            'device changed it first. Showing the current value.',
        beforeValue: 'Your edit: ${otherConflicts.join(', ')}',
        afterValue: 'Kept the other device\'s value',
        entityName: name,
      );
    }
  }

  /// A product update queued by an app version that pushed whole rows. Only
  /// the descriptive fields are applied - stock now belongs to the ledger.
  Future<void> _pushLegacyProductUpdate(
    SyncEvent event,
    Map<String, dynamic> payload,
    String storeId,
  ) async {
    const fields = [
      'barcode',
      'name',
      'mass',
      'category',
      'unit',
      'price',
      'cost_price',
      'low_stock_threshold',
      'image_url',
    ];
    final update = {
      for (final f in fields)
        if (payload.containsKey(f)) f: payload[f],
    };
    if (update.isNotEmpty) {
      await SupabaseService.supabaseClient
          .from('products')
          .update(update)
          .eq('uuid', event.entityUuid)
          .eq('store_id', storeId);
    }
    await _eventQueue.markPushed([event.uuid]);
  }

  // -- credit customers ------------------------------------------------------

  Future<void> _pushCustomerEvents(
    List<SyncEvent> events,
    StoreConfig config,
  ) async {
    final storeId = config.storeId;
    final run = <SyncEvent>[];

    Future<void> flush() async {
      if (run.isEmpty) return;
      await _pushBatched(List.of(run), storeId);
      run.clear();
    }

    for (final event in events) {
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      if (event.operation == 'update') {
        await flush();
        final edit = payload['_edit'] as Map<String, dynamic>?;
        if (edit != null) {
          await _pushCustomerEdit(event, edit, storeId);
        } else {
          await _pushLegacyCustomerUpdate(event, payload, storeId);
        }
      } else {
        run.add(event);
      }
    }
    await flush();
  }

  Future<void> _pushCustomerEdit(
    SyncEvent event,
    Map<String, dynamic> edit,
    String storeId,
  ) async {
    final result = await SupabaseService.supabaseClient.rpc(
      'apply_credit_customer_edit',
      params: {
        'p_uuid': event.entityUuid,
        'p_store_id': storeId,
        'p_base': edit['base'],
        'p_changes': edit['changes'],
      },
    );
    final outcome = Map<String, dynamic>.from(result as Map);
    await _eventQueue.markPushed([event.uuid]);
    if (outcome['found'] != true) return;

    final row = Map<String, dynamic>.from(outcome['row'] as Map);
    await _applier.applyCustomer(row);

    final conflicts = List<String>.from(outcome['conflicts'] as List);
    final riskLog = _riskLog;
    if (conflicts.isEmpty || riskLog == null) return;
    final name = row['name'] as String? ?? 'Customer';
    await riskLog.record(
      type: 'concurrent_credit_edit',
      description:
          'Concurrent edit on $name - your change to ${conflicts.join(', ')} '
          'was not applied because another device changed it first. Showing '
          'the current value.',
      beforeValue: 'Your edit: ${conflicts.join(', ')}',
      afterValue: 'Kept the other device\'s value',
      entityName: name,
    );
  }

  /// A customer update queued by an app version that pushed whole rows
  /// (including a balance the server now owns) - only the descriptive fields
  /// are applied.
  Future<void> _pushLegacyCustomerUpdate(
    SyncEvent event,
    Map<String, dynamic> payload,
    String storeId,
  ) async {
    const fields = ['name', 'phone', 'credit_limit'];
    final update = {
      for (final f in fields)
        if (payload.containsKey(f)) f: payload[f],
    };
    if (update.isNotEmpty) {
      await SupabaseService.supabaseClient
          .from('credit_customers')
          .update(update)
          .eq('uuid', event.entityUuid)
          .eq('store_id', storeId);
    }
    await _eventQueue.markPushed([event.uuid]);
  }

  // -- helpers ---------------------------------------------------------------

  String _signed(Object? value) {
    final n = (value as num?)?.toInt() ?? 0;
    return n >= 0 ? '+$n' : '$n';
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
    // Device-local bookkeeping for a queued edit - the server tables have no
    // such column, it must never reach an upsert.
    payload.remove('_edit');
    payload.remove('_conflict_base');
    // The server owns these: stock and balance only ever change through the
    // ledger triggers, and `updated_at` is stamped by the database.
    if (event.entityType == 'product') {
      payload.remove('stock');
      payload.remove('updated_at');
    } else if (event.entityType == 'credit_customer') {
      payload.remove('balance');
    }
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
