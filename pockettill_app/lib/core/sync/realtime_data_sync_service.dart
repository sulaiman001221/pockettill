import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/product.dart';
import '../../shared/models/return_item.dart';
import '../../shared/models/return_record.dart';
import '../../shared/models/risk_log.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/models/store_config.dart';
import '../database/isar_service.dart';
import '../supabase/supabase_service.dart';
import 'row_mappers.dart';

/// Keeps a device's local sales/returns/risk-log/products live-in-sync with
/// every other device on the same store - the sibling of
/// [RealtimeStockSyncService] (which only ever handled stock quantity).
/// Added 2026-09-09 after two-device testing showed the Sales History,
/// Risk Log, and Stock screens never reflected another device's activity at
/// all: only `stock_events` was ever wired for Realtime or any kind of
/// cross-device pull, so a sale/return/risk-log entry/new-or-edited product
/// made on one device simply never reached another already-populated one -
/// not "slow", genuinely never, since [RestoreService] only ever runs once
/// on an empty local cache.
///
/// Every apply here is idempotent (checked by uuid, or `(sale_uuid,
/// product_uuid)` for [SaleItem] which has no uuid of its own) rather than
/// filtered by device_id - `risk_log` has no `device_id` column to filter
/// on in the first place, and a plain "do I already have this row" check
/// works uniformly for every table (a row this device created is already
/// there before it's ever pushed, so re-seeing it via Realtime is a no-op
/// either way).
///
/// [start] does two things in order, mirroring
/// [RealtimeStockSyncService.start]: a one-off catch-up pull for anything
/// recorded by another device while this one was offline (not just
/// backgrounded - a closed/offline device's Realtime channel isn't
/// running at all), then opens Realtime channels for anything from here on.
class RealtimeDataSyncService {
  RealtimeDataSyncService({required Isar isar}) : _isar = isar;

  final Isar _isar;
  final List<RealtimeChannel> _channels = [];

  final StreamController<void> _salesChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _riskLogChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _productsChangedController =
      StreamController<void>.broadcast();

  /// Emits whenever a remote sale/return has been applied locally - watched
  /// by Sales History to refresh without a manual pull-to-refresh.
  Stream<void> get salesChanged => _salesChangedController.stream;

  /// Emits whenever a remote risk_log entry has been applied locally -
  /// watched by the Risk Log screen.
  Stream<void> get riskLogChanged => _riskLogChangedController.stream;

  /// Emits whenever a remote product insert/update has been applied
  /// locally (a new product, or a price/name/category edit - never stock,
  /// see [_applyRemoteProductUpdate]) - watched by Stock alongside the
  /// existing stock-quantity signal.
  Stream<void> get productsChanged => _productsChangedController.stream;

  /// Runs the catch-up pull, then opens every Realtime channel. A no-op if
  /// already subscribed, if there's no logged-in store, or if either step
  /// fails - this is best-effort background infrastructure, never
  /// something a caller should have to handle a thrown error from.
  Future<void> start() async {
    if (_channels.isNotEmpty) return;

    try {
      final storeConfig = await _isar.storeConfigs.get(1);
      if (storeConfig == null ||
          !storeConfig.isLoggedIn ||
          storeConfig.storeId.isEmpty) {
        return;
      }
      final storeId = storeConfig.storeId;

      await _catchUp(storeConfig);

      _channels.addAll([
        _subscribeInsert(
          table: 'sales',
          storeId: storeId,
          apply: _applyRemoteSale,
        ),
        _subscribeInsert(
          table: 'sale_items',
          storeId: storeId,
          apply: _applyRemoteSaleItem,
        ),
        _subscribeInsert(
          table: 'returns',
          storeId: storeId,
          apply: _applyRemoteReturn,
        ),
        _subscribeInsert(
          table: 'return_items',
          storeId: storeId,
          apply: _applyRemoteReturnItem,
        ),
        _subscribeInsert(
          table: 'risk_log',
          storeId: storeId,
          apply: _applyRemoteRiskLog,
        ),
        _subscribeInsert(
          table: 'products',
          storeId: storeId,
          apply: _applyRemoteNewProduct,
        ),
        _subscribeUpdate(
          table: 'products',
          storeId: storeId,
          apply: _applyRemoteProductUpdate,
        ),
      ]);
    } catch (e) {
      debugPrint('RealtimeDataSyncService.start() failed: $e');
    }
  }

  /// Closes every Realtime channel - call when connectivity drops. [start]
  /// re-opens fresh ones (with their own catch-up) on the next reconnect.
  Future<void> stop() async {
    final channels = List<RealtimeChannel>.from(_channels);
    _channels.clear();
    for (final channel in channels) {
      await SupabaseService.supabaseClient.removeChannel(channel);
    }
  }

  RealtimeChannel _subscribeInsert({
    required String table,
    required String storeId,
    required Future<void> Function(Map<String, dynamic> row) apply,
  }) {
    final channel = SupabaseService.supabaseClient.channel(
      '$table:$storeId:insert',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            unawaited(
              apply(payload.newRecord).catchError((e, st) {
                debugPrint(
                  'RealtimeDataSyncService: apply insert on $table failed: '
                  '$e\n$st',
                );
              }),
            );
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint(
              'RealtimeDataSyncService: $table insert channel error=$error',
            );
          }
        });
    return channel;
  }

  RealtimeChannel _subscribeUpdate({
    required String table,
    required String storeId,
    required Future<void> Function(Map<String, dynamic> row) apply,
  }) {
    final channel = SupabaseService.supabaseClient.channel(
      '$table:$storeId:update',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            unawaited(
              apply(payload.newRecord).catchError((e, st) {
                debugPrint(
                  'RealtimeDataSyncService: apply update on $table failed: '
                  '$e\n$st',
                );
              }),
            );
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint(
              'RealtimeDataSyncService: $table update channel error=$error',
            );
          }
        });
    return channel;
  }

  Future<void> _catchUp(StoreConfig storeConfig) async {
    final since = storeConfig.lastRealtimeDataSyncedAt;
    if (since == null) {
      // First time this feature has run on this device - it already has
      // its own correct local history (this isn't a fresh restore, which
      // goes through RestoreService instead), so there's nothing to
      // retroactively pull. Just establish the watermark, same reasoning
      // as RealtimeStockSyncService's own first-run guard.
      await _updateWatermark(DateTime.now());
      return;
    }

    try {
      final sinceIso = since.toUtc().toIso8601String();
      final storeId = storeConfig.storeId;

      final sales = await _fetchSince('sales', storeId, sinceIso);
      for (final row in sales) {
        await _applyRemoteSale(row);
      }
      // sale_items has no created_at column of its own (see
      // SCHEMA_TRUTH.md) - a plain _fetchSince throws a Postgrest error on
      // it, which (being one shared try/catch) silently aborted the *rest*
      // of this method too, before returns/return_items/risk_log ever got
      // a chance to run. Found 2026-09-09 chasing a risk_log entry that
      // never caught up. Scoping by the parent sales' own uuids instead -
      // every item belonging to a sale this catch-up just pulled - sidesteps
      // needing a timestamp on sale_items at all.
      if (sales.isNotEmpty) {
        final saleUuids = sales.map((row) => row['uuid'] as String).toList();
        final saleItems = await SupabaseService.supabaseClient
            .from('sale_items')
            .select()
            .eq('store_id', storeId)
            .inFilter('sale_uuid', saleUuids);
        for (final row in saleItems) {
          await _applyRemoteSaleItem(row);
        }
      }
      final returns = await _fetchSince('returns', storeId, sinceIso);
      for (final row in returns) {
        await _applyRemoteReturn(row);
      }
      // return_items has no created_at column either - same fix as
      // sale_items above, scoped by the parent returns' own uuids.
      if (returns.isNotEmpty) {
        final returnUuids = returns
            .map((row) => row['uuid'] as String)
            .toList();
        final returnItems = await SupabaseService.supabaseClient
            .from('return_items')
            .select()
            .eq('store_id', storeId)
            .inFilter('return_uuid', returnUuids);
        for (final row in returnItems) {
          await _applyRemoteReturnItem(row);
        }
      }
      final riskLog = await _fetchSince('risk_log', storeId, sinceIso);
      for (final row in riskLog) {
        await _applyRemoteRiskLog(row);
      }

      await _updateWatermark(DateTime.now());
    } catch (e, st) {
      // Best-effort - the next reconnect's catch-up retries from the same
      // (unmoved) watermark.
      debugPrint('RealtimeDataSyncService: catch-up failed: $e\n$st');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSince(
    String table,
    String storeId,
    String sinceIso,
  ) {
    return SupabaseService.supabaseClient
        .from(table)
        .select()
        .eq('store_id', storeId)
        .gt('created_at', sinceIso);
  }

  Future<void> _applyRemoteSale(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.sales.filter().uuidEqualTo(uuid).findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.sales.put(saleFromRow(row));
    });
    _salesChangedController.add(null);
  }

  Future<void> _applyRemoteSaleItem(Map<String, dynamic> row) async {
    final saleUuid = row['sale_uuid'] as String;
    final productUuid = row['product_uuid'] as String;
    final existing = await _isar.saleItems
        .filter()
        .saleUuidEqualTo(saleUuid)
        .and()
        .productUuidEqualTo(productUuid)
        .findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.saleItems.put(saleItemFromRow(row));
    });
  }

  Future<void> _applyRemoteReturn(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.returnRecords
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.returnRecords.put(returnRecordFromRow(row));
    });
    _salesChangedController.add(null);
  }

  Future<void> _applyRemoteReturnItem(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.returnItems
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.returnItems.put(returnItemFromRow(row));
    });
  }

  Future<void> _applyRemoteRiskLog(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.riskLogs
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.riskLogs.put(riskLogFromRow(row));
    });
    _riskLogChangedController.add(null);
  }

  /// A product this device has never seen before, created by another
  /// device. Trusts the row's own `stock` column directly (rather than
  /// leaving it at 0 for RealtimeStockSyncService to build up) - safe
  /// specifically because a brand-new product's `initial_stock` event, if
  /// its own Realtime notification arrives before or after this one, gets
  /// marked "seen" without needing a local product to apply to (see
  /// RealtimeStockSyncService._applyRemoteEvent), so there's no double
  /// application risk the way retroactively trusting the column would be
  /// for a product this device already maintains its own running total for.
  Future<void> _applyRemoteNewProduct(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.products
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.products.put(productFromRow(row));
    });
    _productsChangedController.add(null);
  }

  /// An existing product edited (price/name/category/etc.) on another
  /// device. Deliberately leaves [Product.stock] untouched - the remote
  /// row's own `stock` column isn't kept live-updated by a sale/return/
  /// adjustment (see stock_events' doc comment in SCHEMA_TRUTH.md), so
  /// trusting it here could stomp this device's own correct running total
  /// with a stale value.
  Future<void> _applyRemoteProductUpdate(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.products
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing == null) {
      // Never seen this product at all - same as a fresh insert.
      await _applyRemoteNewProduct(row);
      return;
    }

    final updated = productFromRow(row)
      ..id = existing.id
      ..stock = existing.stock
      ..cachedImagePath = existing.cachedImagePath
      ..catalogueSyncedImageUrl = existing.catalogueSyncedImageUrl;
    await _isar.writeTxn(() async {
      await _isar.products.put(updated);
    });
    _productsChangedController.add(null);
  }

  Future<void> _updateWatermark(DateTime at) async {
    final config = await _isar.storeConfigs.get(1);
    if (config == null) return;
    config.lastRealtimeDataSyncedAt = at;
    await _isar.writeTxn(() async {
      await _isar.storeConfigs.put(config);
    });
  }

  /// Stops every channel and closes the streams.
  Future<void> dispose() async {
    await stop();
    await _salesChangedController.close();
    await _riskLogChangedController.close();
    await _productsChangedController.close();
  }
}

/// The app-wide [RealtimeDataSyncService] singleton.
final realtimeDataSyncServiceProvider = Provider<RealtimeDataSyncService>((
  ref,
) {
  return RealtimeDataSyncService(isar: ref.watch(isarProvider));
});

/// Watched by Sales History to refresh when another device's sale/return
/// lands.
final salesDataChangedProvider = StreamProvider<void>((ref) {
  return ref.watch(realtimeDataSyncServiceProvider).salesChanged;
});

/// Watched by the Risk Log screen to refresh when another device logs an
/// entry.
final riskLogChangedProvider = StreamProvider<void>((ref) {
  return ref.watch(realtimeDataSyncServiceProvider).riskLogChanged;
});

/// Watched by Stock to refresh when another device creates or edits a
/// product.
final productsChangedProvider = StreamProvider<void>((ref) {
  return ref.watch(realtimeDataSyncServiceProvider).productsChanged;
});
