import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/product.dart';
import '../../shared/models/stock_event.dart';
import '../../shared/models/store_config.dart';
import '../../shared/repositories/product_repository.dart';
import '../../shared/repositories/repositories.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';

/// Keeps a device's local stock live-in-sync with every other device
/// selling the same store's products, on top of the delta events
/// [ProductRepository.recordStockEvent] already records for the regular
/// push pipeline - see `stock_events` in SCHEMA_TRUTH.md and the
/// multi-device sync plan (2026-09-09) for the full design.
///
/// [start] does two things in order: a one-off catch-up pull (anything
/// recorded by another device while this one was offline/unsubscribed),
/// then opens a Realtime channel for anything from here on. Both apply a
/// remote delta to the matching local `Product.stock` exactly once - own
/// events are skipped outright (this device already applied them at
/// creation time), and every applied event is recorded locally by its
/// server-assigned id so a duplicate delivery (catch-up and Realtime both
/// seeing the same row in a reconnect race) can't double-apply.
class RealtimeStockSyncService {
  RealtimeStockSyncService({
    required Isar isar,
    required ProductRepository productRepository,
  }) : _isar = isar,
       _productRepository = productRepository;

  final Isar _isar;
  final ProductRepository _productRepository;
  RealtimeChannel? _channel;

  final StreamController<void> _stockChangedController =
      StreamController<void>.broadcast();

  /// Emits whenever a remote device's stock change has been applied
  /// locally - watched by screens showing live stock (Stock's list) so
  /// they refresh without the user pulling to refresh themselves.
  Stream<void> get stockChanged => _stockChangedController.stream;

  /// Runs the catch-up pull, then opens the Realtime channel. A no-op if
  /// already subscribed, if there's no logged-in store, or if either step
  /// fails - this is best-effort background infrastructure, never
  /// something a caller should have to handle a thrown error from.
  Future<void> start() async {
    if (_channel != null) return;

    try {
      final storeConfig = await _isar.storeConfigs.get(1);
      if (storeConfig == null ||
          !storeConfig.isLoggedIn ||
          storeConfig.storeId.isEmpty) {
        return;
      }

      await _catchUp(storeConfig);

      final channel = SupabaseService.supabaseClient.channel(
        'stock_events:${storeConfig.storeId}',
      );
      channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'stock_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeConfig.storeId,
            ),
            callback: (payload) => unawaited(
              _handleRemoteEvent(payload.newRecord, storeConfig.deviceId),
            ),
          )
          .subscribe((status, error) {
            if (error != null) {
              debugPrint('RealtimeStockSyncService: channel error=$error');
            }
          });
      _channel = channel;
    } catch (e) {
      debugPrint('RealtimeStockSyncService.start() failed: $e');
    }
  }

  /// Closes the Realtime channel - call when connectivity drops, so a dead
  /// subscription doesn't sit around silently not delivering anything.
  /// [start] re-opens a fresh one (with its own catch-up) on the next
  /// reconnect.
  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await SupabaseService.supabaseClient.removeChannel(channel);
    }
  }

  Future<void> _catchUp(StoreConfig storeConfig) async {
    try {
      if (storeConfig.lastStockEventSyncedAt == null) {
        // First time this feature has ever run on this device. Its local
        // Product.stock already reflects reality as of right now (this
        // device existed and sold things before stock_events did), so
        // treating "no watermark yet" as "fetch every historical event"
        // would double-count everything already baked into that stock -
        // most visibly the one-time initial_stock migration backfill, which
        // is just a snapshot of what was already there. Only establish the
        // watermark; RestoreService seeds it the same way on a fresh
        // restore, for the same reason. Found 2026-09-08 after a live test
        // showed a product's stock inflated by exactly its own backfill
        // amount.
        final latest = await SupabaseService.fetchLatestStockEventSyncedAt(
          storeConfig.storeId,
        );
        if (latest != null) {
          await _updateLastSeen(latest);
        }
        return;
      }

      final rows = await SupabaseService.fetchMissedStockEvents(
        storeId: storeConfig.storeId,
        excludingDeviceId: storeConfig.deviceId,
        since: storeConfig.lastStockEventSyncedAt,
      );
      for (final row in rows) {
        await _applyRemoteEvent(row);
      }
      if (rows.isNotEmpty) {
        final maxSyncedAt = rows
            .map((row) => DateTime.parse(row['synced_at'] as String).toLocal())
            .reduce((a, b) => a.isAfter(b) ? a : b);
        await _updateLastSeen(maxSyncedAt);
      }
    } catch (_) {
      // Best-effort - the next reconnect's catch-up retries from the same
      // (unmoved) high-water mark.
    }
  }

  Future<void> _handleRemoteEvent(
    Map<String, dynamic> row,
    String myDeviceId,
  ) async {
    // Postgres change notifications go to every subscriber, including the
    // one that made the write - this device already applied its own delta
    // to Product.stock the moment it created the event, so re-applying it
    // here would double-count.
    if (row['device_id'] == myDeviceId) return;

    await _applyRemoteEvent(row);
    final syncedAtRaw = row['synced_at'] as String?;
    final syncedAt = syncedAtRaw != null
        ? DateTime.parse(syncedAtRaw).toLocal()
        : DateTime.now();
    await _updateLastSeen(syncedAt);
  }

  Future<void> _applyRemoteEvent(Map<String, dynamic> row) async {
    final eventUuid = row['id'] as String;

    // Idempotency against duplicate delivery - a reconnect's catch-up query
    // and a live Realtime insert can both see the same row in a narrow
    // timing window. StockEvent.uuid is a unique index, so re-`put`ting the
    // same id is harmless on its own, but the stock delta below must still
    // only ever apply once.
    final alreadyApplied = await _isar.stockEvents
        .filter()
        .uuidEqualTo(eventUuid)
        .findFirst();
    if (alreadyApplied != null) return;

    final productUuid = row['product_id'] as String;
    final delta = row['quantity_delta'] as int;
    final product = await _productRepository.getByUuid(productUuid);

    await _isar.writeTxn(() async {
      if (product != null) {
        product.stock += delta;
        await _isar.products.put(product);
      }
      await _isar.stockEvents.put(
        StockEvent()
          ..uuid = eventUuid
          ..productUuid = productUuid
          ..deviceId = row['device_id'] as String
          ..changeType = row['change_type'] as String
          ..quantityDelta = delta
          ..referenceId = row['reference_id'] as String?
          ..createdAt = DateTime.parse(row['created_at'] as String).toLocal()
          ..synced = true,
      );
    });

    _stockChangedController.add(null);
  }

  Future<void> _updateLastSeen(DateTime syncedAt) async {
    final config = await _isar.storeConfigs.get(1);
    if (config == null) return;
    final current = config.lastStockEventSyncedAt;
    if (current != null && !syncedAt.isAfter(current)) return;

    config.lastStockEventSyncedAt = syncedAt;
    await _isar.writeTxn(() async {
      await _isar.storeConfigs.put(config);
    });
  }

  /// Stops the channel and closes [stockChanged].
  Future<void> dispose() async {
    await stop();
    await _stockChangedController.close();
  }
}

/// The app-wide [RealtimeStockSyncService] singleton.
final realtimeStockSyncServiceProvider = Provider<RealtimeStockSyncService>((
  ref,
) {
  return RealtimeStockSyncService(
    isar: ref.watch(isarProvider),
    productRepository: ref.watch(productRepositoryProvider),
  );
});

/// Watched by screens showing live stock (Stock's list) to refresh when
/// another device's sale/return/adjustment lands.
final stockChangedProvider = StreamProvider<void>((ref) {
  return ref.watch(realtimeStockSyncServiceProvider).stockChanged;
});
