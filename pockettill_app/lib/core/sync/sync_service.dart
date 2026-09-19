import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/product.dart';
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
///
/// `credit_customer` must come before `credit_tx` for a related but
/// distinct reason (no FK involved, unlike product/stock_event above):
/// _resolveCreditCustomerConflicts needs to discard a manual_credit/
/// writeoff transaction's own credit_tx event when the balance change it
/// represents gets reverted for conflicting with another device's edit -
/// which only works if that credit_tx event hasn't already been pushed to
/// Supabase by the time the conflict is detected.
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

        // Populated by conflict resolution below with event uuids that
        // must never reach the normal push loop, whichever entity type
        // they belong to - a reverted product edit's own events (already
        // marked pushed) and its orphaned manual-adjustment stock_event
        // (already discarded outright). Checked here rather than removing
        // straight from `eventsByType` so `stock_event`'s own entry
        // (processed in a later loop iteration than `product`) still
        // reflects the exclusion by the time its turn comes.
        final handledEventUuids = <String>{};

        for (final entityType in _entityTypePriority) {
          final typeEvents = eventsByType[entityType];
          if (typeEvents == null || typeEvents.isEmpty) continue;

          // Checked before pushing, not after: once this device's own
          // write lands, the remote row becomes *this* device's edit, so
          // there'd be nothing left to compare against.
          if (entityType == 'product') {
            handledEventUuids.addAll(
              await _resolveProductConflicts(
                typeEvents,
                eventsByType['stock_event'] ?? const [],
                storeId,
              ),
            );
          }
          if (entityType == 'credit_customer') {
            handledEventUuids.addAll(
              await _resolveCreditCustomerConflicts(
                typeEvents,
                eventsByType['credit_tx'] ?? const [],
                storeId,
              ),
            );
          }

          final events = typeEvents
              .where((e) => !handledEventUuids.contains(e.uuid))
              .toList();
          if (events.isEmpty) continue;

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

  /// Optimistic-concurrency conflict resolution for a product edit (name,
  /// price, category, mass, or a manual stock-quantity edit made through
  /// the Edit Product form).
  ///
  /// Replaces the old "log it but let last-write-wins proceed anyway"
  /// behaviour (2026-09-12 - see git history) with an actual revert:
  /// requested 2026-09-13 after two-device testing, since a silently
  /// overwritten edit is exactly the kind of thing a spaza shop owner
  /// needs to *know* happened, not just have vanish. When Device A and
  /// Device B both edit the same product from the same starting point
  /// while both offline, neither edit wins - both discard, every tracked
  /// field reverts to what it was before either device touched it, and a
  /// Risk Log entry records it.
  ///
  /// [ProductRepository.save] captures that starting point (name, price,
  /// category, mass, stock) as `payload['_conflict_base']` at the moment
  /// editing begins - never part of the row actually sent to Supabase (see
  /// [_toEventMap], which strips it before every push), just this device's
  /// own record of "what I started from".
  ///
  /// Deliberately never triggered by a sale/return/quick-restock (see
  /// [ProductRepository.adjustStock]) - those never carry a
  /// `_conflict_base` at all, since two devices selling the same product
  /// offline is the normal, expected case the whole stock_events delta
  /// model exists to handle correctly (both deltas should apply), not a
  /// conflict. Only a manual edit through the product form - where the
  /// owner types a new absolute number, not an intentional "+N"/"-N" - can
  /// genuinely race the way name/price/category can.
  ///
  /// Every tracked field is checked and applied by a single Postgres RPC
  /// call (`apply_product_edit`) rather than this method reading the
  /// remote row, deciding, and pushing separately - the previous version
  /// did exactly that, and it had a real race: the read and the later
  /// write were two separate round-trips, so two devices racing each
  /// other could both read "no conflict yet" before either had actually
  /// pushed, and both would go on to push their own value with the
  /// conflict never detected at all. Found 2026-09-16 after two-device
  /// testing produced zero concurrent_product_edit/concurrent_stock_edit
  /// risk_log entries despite deliberately racing two devices repeatedly.
  /// A single `UPDATE ... WHERE <matches expected>` (or the revert branch)
  /// inside one transaction can't have that race - Postgres's own row lock
  /// serializes concurrent calls, so whichever call runs second always
  /// sees the first call's effect already applied.
  ///
  /// Returns every [SyncEvent.uuid] this method has already resolved one
  /// way or another (applied cleanly via the RPC, or reverted) - excluded
  /// from the caller's own push loop this cycle, since pushing them again
  /// through the normal path would try to apply their original values a
  /// second time, undoing whatever the RPC just did.
  Future<Set<String>> _resolveProductConflicts(
    List<SyncEvent> productEvents,
    List<SyncEvent> stockEvents,
    String storeId,
  ) async {
    final handledEventUuids = <String>{};
    final riskLog = _riskLog;
    if (riskLog == null) return handledEventUuids;

    // Multiple pending edits to the same product collapse to just the
    // latest before ever reaching the RPC - checking every one of them
    // would just re-resolve the same product repeatedly against stale
    // intermediate states. Events arrive oldest-first
    // (EventQueue.getPending), so the last assignment per uuid below is
    // the one that reflects this device's actual current intent.
    final withBase = <String, SyncEvent>{};
    for (final event in productEvents) {
      if (event.baseUpdatedAt != null) withBase[event.entityUuid] = event;
    }
    if (withBase.isEmpty) return handledEventUuids;

    for (final entry in withBase.entries) {
      final productUuid = entry.key;
      final event = entry.value;
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      final base = payload['_conflict_base'] as Map<String, dynamic>?;

      // An event queued before this feature existed - nothing captured to
      // check against, so leave it to the normal push path (plain
      // last-write-wins) rather than guessing.
      if (base == null) continue;

      final thisProductEventUuids = productEvents
          .where((e) => e.entityUuid == productUuid)
          .map((e) => e.uuid)
          .toList();

      try {
        final rows = await SupabaseService.supabaseClient.rpc(
          'apply_product_edit',
          params: {
            'p_uuid': productUuid,
            'p_store_id': storeId,
            'p_expected_name': base['name'],
            'p_expected_price': base['price'],
            'p_expected_category': base['category'],
            'p_expected_mass': base['mass'],
            'p_expected_stock': base['stock'],
            'p_new_name': payload['name'],
            'p_new_price': payload['price'],
            'p_new_category': payload['category'],
            'p_new_mass': payload['mass'],
            'p_new_stock': payload['stock'],
          },
        );
        final result = (rows as List).first as Map<String, dynamic>;
        final conflict = result['conflict'] as bool;
        final finalName = result['final_name'] as String?;

        // Either way, the RPC has already fully applied (or reverted) the
        // row remotely - this device's own pending event(s) for it must
        // never also go through the normal push path afterward, or
        // they'd stomp the RPC's result with their original values.
        await _eventQueue.markPushed(thisProductEventUuids);
        handledEventUuids.addAll(thisProductEventUuids);

        // The manual stock-quantity edit this same Edit Product save
        // recorded (see ProductRepository.save) is a *separate* pending
        // stock_event - the RPC already applied (or reverted) the
        // absolute stock value directly, so this delta-shaped event must
        // never additionally apply on top of that, conflict or not.
        // Matched by product + change_type since stock_events has no
        // link back to the product edit that caused it - safe because a
        // manual form edit and its own stock delta are always enqueued
        // together, one right after the other (see save), and a product
        // isn't normally mid-edit on the same device twice before the
        // first edit ever gets a chance to sync.
        final orphanedStockEventUuids = <String>[
          for (final stockSyncEvent in stockEvents)
            if ((jsonDecode(stockSyncEvent.payload)
                    as Map<String, dynamic>)['product_id'] ==
                productUuid &&
                (jsonDecode(stockSyncEvent.payload)
                        as Map<String, dynamic>)['change_type'] ==
                    'manual_adjustment')
              stockSyncEvent.uuid,
        ];
        await _eventQueue.discard(orphanedStockEventUuids);
        handledEventUuids.addAll(orphanedStockEventUuids);

        // Local copy always follows the RPC's verdict - win or revert -
        // so this device shows the true row instead of its own
        // now-possibly-discarded edit until some other change happens to
        // echo back over Realtime.
        if (finalName != null) {
          final localProduct = await _isar.products
              .filter()
              .uuidEqualTo(productUuid)
              .findFirst();
          if (localProduct != null) {
            localProduct
              ..name = finalName
              ..price =
                  (result['final_price'] as num?)?.toDouble() ??
                  localProduct.price
              ..category = result['final_category'] as String?
              ..mass = result['final_mass'] as String?
              ..stock =
                  (result['final_stock'] as num?)?.toInt() ??
                  localProduct.stock
              ..updatedAt = DateTime.now();
            await _isar.writeTxn(() async {
              await _isar.products.put(localProduct);
            });
          }
        }

        if (!conflict) continue;

        final name = finalName ?? payload['name'] as String? ?? 'Product';
        final baseStock = (base['stock'] as num).toInt();
        final stockConflicted =
            (payload['stock'] as num?)?.toInt() != baseStock;
        final metadataConflicted =
            payload['name'] != base['name'] ||
            (payload['price'] as num?)?.toDouble() !=
                (base['price'] as num?)?.toDouble() ||
            payload['category'] != base['category'] ||
            payload['mass'] != base['mass'];

        if (stockConflicted) {
          await riskLog.record(
            type: 'concurrent_stock_edit',
            description:
                'Concurrent stock quantity edit on $name - changes '
                'discarded. Original quantity restored.',
            beforeValue: '$baseStock',
            afterValue: null,
            entityName: name,
          );
        }
        if (metadataConflicted) {
          await riskLog.record(
            type: 'concurrent_product_edit',
            description:
                'Concurrent edit conflict on $name - changes from both '
                'devices discarded. Original value restored.',
            beforeValue: base['name'] as String? ?? '',
            afterValue: payload['name'] as String?,
            entityName: name,
          );
        }
      } catch (e, st) {
        // Best-effort - a failed RPC call must never block the actual
        // push; falling through leaves this event pending, so the normal
        // push path (or a retry of this same check next cycle) still gets
        // a turn at it.
        debugPrint(
          'SyncService._resolveProductConflicts: RPC failed for '
          '$productUuid: $e\n$st',
        );
      }
    }
    return handledEventUuids;
  }

  /// Same atomic-RPC conflict resolution as [_resolveProductConflicts], for
  /// a credit customer's directly-editable fields (name, phone, credit
  /// limit) and a manual balance change (a `manual_credit`/`writeoff`
  /// adjustment with no purchase/repayment transaction backing it - see
  /// [CreditRepository.addManualCredit]/[CreditRepository.writeOffBalance]).
  /// A real purchase or repayment is event-sourced like a sale, always
  /// applying regardless of what else happened - only these "manual edit"
  /// operations, which [CreditRepository] marks with a `_conflict_base`
  /// snapshot, go through this at all.
  Future<Set<String>> _resolveCreditCustomerConflicts(
    List<SyncEvent> customerEvents,
    List<SyncEvent> txEvents,
    String storeId,
  ) async {
    final handledEventUuids = <String>{};
    final riskLog = _riskLog;
    if (riskLog == null) return handledEventUuids;

    final withBase = <String, SyncEvent>{};
    for (final event in customerEvents) {
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      if (payload['_conflict_base'] != null) {
        withBase[event.entityUuid] = event;
      }
    }
    if (withBase.isEmpty) return handledEventUuids;

    for (final entry in withBase.entries) {
      final customerUuid = entry.key;
      final event = entry.value;
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      final base = payload['_conflict_base'] as Map<String, dynamic>;

      final thisCustomerEventUuids = customerEvents
          .where((e) => e.entityUuid == customerUuid)
          .map((e) => e.uuid)
          .toList();

      try {
        final rows = await SupabaseService.supabaseClient.rpc(
          'apply_credit_customer_edit',
          params: {
            'p_uuid': customerUuid,
            'p_store_id': storeId,
            'p_expected_name': base['name'],
            'p_expected_phone': base['phone'],
            'p_expected_balance': base['balance'],
            'p_expected_credit_limit': base['credit_limit'],
            'p_new_name': payload['name'],
            'p_new_phone': payload['phone'],
            'p_new_balance': payload['balance'],
            'p_new_credit_limit': payload['credit_limit'],
          },
        );
        final result = (rows as List).first as Map<String, dynamic>;
        final conflict = result['conflict'] as bool;
        final finalName = result['final_name'] as String?;

        await _eventQueue.markPushed(thisCustomerEventUuids);
        handledEventUuids.addAll(thisCustomerEventUuids);

        // The manual_credit/writeoff transaction this same edit recorded
        // (see CreditRepository.addManualCredit/writeOffBalance) is a
        // separate pending credit_tx event - the RPC already applied (or
        // reverted) the balance directly, so this transaction record must
        // never additionally apply on top of that, conflict or not.
        final orphanedTxUuids = <String>[
          for (final txEvent in txEvents)
            if ((jsonDecode(txEvent.payload)
                    as Map<String, dynamic>)['customer_id'] ==
                customerUuid &&
                const {
                  'manual_credit',
                  'writeoff',
                }.contains(
                  (jsonDecode(txEvent.payload) as Map<String, dynamic>)['type'],
                ))
              txEvent.uuid,
        ];
        await _eventQueue.discard(orphanedTxUuids);
        handledEventUuids.addAll(orphanedTxUuids);

        if (finalName != null) {
          final localCustomer = await _isar.creditCustomers
              .filter()
              .uuidEqualTo(customerUuid)
              .findFirst();
          if (localCustomer != null) {
            localCustomer
              ..name = finalName
              ..phone = result['final_phone'] as String?
              ..balance =
                  (result['final_balance'] as num?)?.toDouble() ??
                  localCustomer.balance
              ..creditLimit = (result['final_credit_limit'] as num?)
                  ?.toDouble()
              ..lastActivityAt = DateTime.now();
            await _isar.writeTxn(() async {
              await _isar.creditCustomers.put(localCustomer);
            });
          }
        }

        if (!conflict) continue;

        final name = finalName ?? payload['name'] as String? ?? 'Customer';
        await riskLog.record(
          type: 'concurrent_credit_edit',
          description:
              'Concurrent edit conflict on $name - changes from both '
              'devices discarded. Original value restored.',
          beforeValue: base['balance'] != null
              ? 'R${(base['balance'] as num).toStringAsFixed(2)}'
              : (base['name'] as String? ?? ''),
          afterValue: null,
          entityName: name,
        );
      } catch (e, st) {
        debugPrint(
          'SyncService._resolveCreditCustomerConflicts: RPC failed for '
          '$customerUuid: $e\n$st',
        );
      }
    }
    return handledEventUuids;
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
    // This device's own pre-edit snapshot for conflict resolution (see
    // ProductRepository.save/_resolveProductConflicts) - `products` has no
    // column for it, it must never reach the actual upsert.
    payload.remove('_conflict_base');
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
