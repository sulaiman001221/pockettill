import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/extra_income.dart';
import '../../shared/models/product.dart';
import '../../shared/models/return_item.dart';
import '../../shared/models/return_record.dart';
import '../../shared/models/risk_log.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/models/stock_event.dart';
import '../../shared/models/store_config.dart';
import '../../shared/repositories/credit_repository.dart';
import '../database/isar_service.dart';
import '../storage/image_cache_service.dart';
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
  final StreamController<void> _storeProfileChangedController =
      StreamController<void>.broadcast();
  final StreamController<void> _creditChangedController =
      StreamController<void>.broadcast();
  final StreamController<String> _productDeletedController =
      StreamController<String>.broadcast();
  final StreamController<String> _customerDeletedController =
      StreamController<String>.broadcast();

  /// Emits whenever a remote sale/return/extra-income entry has been
  /// applied locally - watched by Sales History to refresh without a
  /// manual pull-to-refresh.
  Stream<void> get salesChanged => _salesChangedController.stream;

  /// Emits whenever a remote risk_log entry has been applied locally -
  /// watched by the Risk Log screen.
  Stream<void> get riskLogChanged => _riskLogChangedController.stream;

  /// Emits whenever a remote product insert/update has been applied
  /// locally (a new product, or a price/name/category edit - never stock,
  /// see [_applyRemoteProductUpdate]) - watched by Stock alongside the
  /// existing stock-quantity signal.
  Stream<void> get productsChanged => _productsChangedController.stream;

  /// Emits whenever another device's Settings edit (store name, owner
  /// name/phone, address) has been applied locally - watched by the
  /// Settings screen.
  Stream<void> get storeProfileChanged => _storeProfileChangedController.stream;

  /// Emits whenever a remote credit_customer or credit_transaction change
  /// (new/edited/deleted customer, a repayment or credit adjustment) has
  /// been applied locally - watched by the Customers list and Customer
  /// Detail.
  Stream<void> get creditChanged => _creditChangedController.stream;

  /// Emits the uuid of a product deleted on another device, once removed
  /// locally - watched by a currently-open product edit screen so it can
  /// navigate back with an explanatory message instead of continuing to
  /// edit a row that no longer exists.
  Stream<String> get productDeleted => _productDeletedController.stream;

  /// Emits the uuid of a credit customer deleted on another device, once
  /// removed locally - watched by a currently-open Customer Detail screen
  /// for the same reason as [productDeleted].
  Stream<String> get customerDeleted => _customerDeletedController.stream;

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
      await _reconcileProducts(storeId);

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
        // products' delete payload only reliably carries its primary key
        // (uuid), not store_id - see REPLICA IDENTITY FULL note in
        // SCHEMA_TRUTH.md, needed for Realtime to deliver this at all.
        _subscribeDelete(
          table: 'products',
          storeId: storeId,
          apply: _applyRemoteProductDelete,
        ),
        _subscribeInsert(
          table: 'extra_income',
          storeId: storeId,
          apply: _applyRemoteExtraIncome,
        ),
        // stores has no store_id column - the row's own primary key *is*
        // the store id, so this filters on that column instead.
        _subscribeUpdate(
          table: 'stores',
          storeId: storeId,
          filterColumn: 'uuid',
          apply: _applyRemoteStoreProfile,
        ),
        _subscribeInsert(
          table: 'credit_customers',
          storeId: storeId,
          apply: _applyRemoteCreditCustomerInsert,
        ),
        _subscribeUpdate(
          table: 'credit_customers',
          storeId: storeId,
          apply: _applyRemoteCreditCustomerUpdate,
        ),
        _subscribeDelete(
          table: 'credit_customers',
          storeId: storeId,
          apply: _applyRemoteCreditCustomerDelete,
        ),
        _subscribeInsert(
          table: 'credit_transactions',
          storeId: storeId,
          apply: _applyRemoteCreditTransaction,
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
    String filterColumn = 'store_id',
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
            column: filterColumn,
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
    String filterColumn = 'store_id',
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
            column: filterColumn,
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

  /// Unlike insert/update, a delete payload's `oldRecord` only reliably
  /// carries the row's primary key (Postgres' default REPLICA IDENTITY) -
  /// not `store_id`, so this can't filter server-side by store the same
  /// way. Filters client-side per row instead; the volume of deletes on
  /// any of these tables is low enough that this is a non-issue.
  RealtimeChannel _subscribeDelete({
    required String table,
    required String storeId,
    required Future<void> Function(Map<String, dynamic> oldRow) apply,
  }) {
    final channel = SupabaseService.supabaseClient.channel(
      '$table:$storeId:delete',
    );
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: table,
          callback: (payload) {
            unawaited(
              apply(payload.oldRecord).catchError((e, st) {
                debugPrint(
                  'RealtimeDataSyncService: apply delete on $table failed: '
                  '$e\n$st',
                );
              }),
            );
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint(
              'RealtimeDataSyncService: $table delete channel error=$error',
            );
          }
        });
    return channel;
  }

  /// Full reconciliation for `products` - compares every product uuid this
  /// store has in Supabase against what's known locally and pulls down
  /// anything missing, regardless of [_catchUp]'s watermark. The
  /// watermark-based catch-up only ever looks forward from a point in time
  /// (and, on its very first run on a device, doesn't look backward at
  /// all - see its own comment), so a device that missed products entirely
  /// before multi-device sync existed, or before this device's watermark
  /// was ever established, has no other path to ever catch up on them.
  /// Runs every time [start] runs (every app startup while online), not
  /// just once - cheap (a single uuid-only query for the common case of
  /// nothing missing) and self-correcting if it's ever missed a gap
  /// before. Found 2026-09-13 on a real two-device store: one device stuck
  /// at 20 products, the other correctly at 25.
  Future<void> _reconcileProducts(String storeId) async {
    try {
      final remoteRows = await SupabaseService.supabaseClient
          .from('products')
          .select('uuid')
          .eq('store_id', storeId);
      final remoteUuids = remoteRows.map((row) => row['uuid'] as String).toSet();

      final localProducts = await _isar.products.where().findAll();
      final localUuids = localProducts.map((p) => p.uuid).toSet();

      final missing = remoteUuids.difference(localUuids);
      if (missing.isEmpty) return;

      final missingRows = await SupabaseService.supabaseClient
          .from('products')
          .select()
          .eq('store_id', storeId)
          .inFilter('uuid', missing.toList());
      for (final row in missingRows) {
        await _applyRemoteNewProduct(row);
      }
    } catch (e) {
      debugPrint('RealtimeDataSyncService: product reconciliation failed: $e');
    }
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
      final extraIncome = await _fetchSince('extra_income', storeId, sinceIso);
      for (final row in extraIncome) {
        await _applyRemoteExtraIncome(row);
      }
      final creditCustomers = await _fetchSince(
        'credit_customers',
        storeId,
        sinceIso,
      );
      for (final row in creditCustomers) {
        await _applyRemoteCreditCustomerUpdate(row);
      }
      final creditTransactions = await _fetchSince(
        'credit_transactions',
        storeId,
        sinceIso,
      );
      for (final row in creditTransactions) {
        await _applyRemoteCreditTransaction(row);
      }
      // stores has just the one row for this store - no date range to
      // catch up over, just re-fetch and apply its current state.
      final storeRows = await SupabaseService.supabaseClient
          .from('stores')
          .select()
          .eq('uuid', storeId);
      if (storeRows.isNotEmpty) {
        await _applyRemoteStoreProfile(storeRows.first);
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

  Future<void> _applyRemoteExtraIncome(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.extraIncomes
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.extraIncomes.put(extraIncomeFromRow(row));
    });
    // Reuses the Sales History refresh signal - extra income shows up
    // there alongside sales/returns, not on a screen of its own.
    _salesChangedController.add(null);
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

  /// An existing product edited (price/name/category/image/etc.) on another
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

    final newImageUrl = row['image_url'] as String?;
    // A cached file keyed by the OLD imageUrl is now wrong the moment the
    // image actually changes (replaced with a different photo) or is
    // removed (imageUrl now null) - mirrors ProductRepository.save()'s own
    // cache-invalidation for a *local* edit. Missing here meant a remote
    // image replace/removal never showed up on this device at all: the
    // display widget prefers cachedImagePath over imageUrl whenever the
    // cached file still exists on disk (see CachedProductImage), so a
    // stale file kept winning indefinitely. Found 2026-09-12.
    final imageChanged = existing.imageUrl != newImageUrl;
    if (imageChanged) {
      await ImageCacheService.deleteCachedFile(existing.barcode);
    }

    final updated = productFromRow(row)
      ..id = existing.id
      ..stock = existing.stock
      ..cachedImagePath = imageChanged ? null : existing.cachedImagePath
      ..catalogueSyncedImageUrl = imageChanged
          ? null
          : existing.catalogueSyncedImageUrl;
    await _isar.writeTxn(() async {
      await _isar.products.put(updated);
    });
    _productsChangedController.add(null);
  }

  /// A product deleted on another device. Postgres only guarantees a
  /// delete payload's `oldRecord` carries the primary key (`uuid`) - not
  /// the full row - mirrors [_applyRemoteCreditCustomerDelete]. Also
  /// removes its stock_events locally (already cascaded remotely, see
  /// SCHEMA_TRUTH.md) so nothing on this device's own ledger still
  /// references a product that no longer exists.
  Future<void> _applyRemoteProductDelete(Map<String, dynamic> oldRow) async {
    final uuid = oldRow['uuid'] as String?;
    if (uuid == null) return;
    final existing = await _isar.products.filter().uuidEqualTo(uuid).findFirst();
    if (existing == null) return;

    await _isar.writeTxn(() async {
      final eventIds = await _isar.stockEvents
          .filter()
          .productUuidEqualTo(uuid)
          .idProperty()
          .findAll();
      if (eventIds.isNotEmpty) {
        await _isar.stockEvents.deleteAll(eventIds);
      }
      await _isar.products.delete(existing.id);
    });
    await ImageCacheService.deleteCachedFile(existing.barcode);
    _productsChangedController.add(null);
    _productDeletedController.add(uuid);
  }

  /// Another device's Settings edit (store name, owner name/phone,
  /// address, or the Product Images toggles) - only touches the specific
  /// profile fields `_enqueueStoreProfileSync` actually pushes, never this
  /// device's own local-only state (deviceId, sound prefs, sync
  /// timestamps, login state).
  ///
  /// `stores` gets updated for reasons Settings doesn't care about too -
  /// `check_founding_store_qualification` stamps `qualification_checked_at`
  /// on every call, for instance - and every one of those still fires this
  /// device's own `stores:update` Realtime subscription (filtered by store
  /// id only, so a device sees its own writes echoed back same as any other
  /// device's). Unconditionally firing [_storeProfileChangedController] on
  /// every such row change created a genuine infinite loop: Settings opens
  /// -> calls that RPC -> RPC writes the row -> this device's own channel
  /// echoes it -> signal fires -> Settings' listener reloads -> calls the
  /// RPC again - bounded only by round-trip latency, which read as
  /// "refreshing every second". Found 2026-09-12. Comparing against the
  /// fields actually applied below (and skipping the write/signal
  /// entirely when none of them changed) breaks the loop at its root
  /// instead of just changing what Settings does in response to it.
  Future<void> _applyRemoteStoreProfile(Map<String, dynamic> row) async {
    final config = await _isar.storeConfigs.get(1);
    if (config == null) return;

    final newStoreName = row['name'] as String? ?? config.storeName;
    final newOwnerName = row['owner_name'] as String? ?? config.ownerName;
    final newOwnerPhone = row['owner_phone'] as String? ?? config.ownerPhone;
    final newAddress = row['address'] as String?;
    final newUseCatalogueImages =
        row['use_catalogue_images'] as bool? ?? config.useCatalogueImages;
    final newImagesWifiOnly =
        row['images_wifi_only'] as bool? ?? config.imagesWifiOnly;

    final unchanged =
        config.storeName == newStoreName &&
        config.ownerName == newOwnerName &&
        config.ownerPhone == newOwnerPhone &&
        config.address == newAddress &&
        config.useCatalogueImages == newUseCatalogueImages &&
        config.imagesWifiOnly == newImagesWifiOnly;
    if (unchanged) return;

    config
      ..storeName = newStoreName
      ..ownerName = newOwnerName
      ..ownerPhone = newOwnerPhone
      ..address = newAddress
      ..useCatalogueImages = newUseCatalogueImages
      ..imagesWifiOnly = newImagesWifiOnly;
    await _isar.writeTxn(() async {
      await _isar.storeConfigs.put(config);
    });
    _storeProfileChangedController.add(null);
  }

  Future<void> _applyRemoteCreditCustomerInsert(
    Map<String, dynamic> row,
  ) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.creditCustomers
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing != null) return;
    await _isar.writeTxn(() async {
      await _isar.creditCustomers.put(creditCustomerFromRow(row));
    });
    await _recomputeCreditBalance(uuid, row['store_id'] as String);
    _creditChangedController.add(null);
  }

  /// An existing customer's credit limit or details changed on another
  /// device - or, per [_recomputeCreditBalance] below, a repayment/manual
  /// credit adjustment (any credit-related change ends up here or in
  /// [_applyRemoteCreditTransaction], both of which recompute). Also
  /// handles a customer this device hasn't seen at all yet (same as a
  /// fresh insert), which is exactly what a first-run catch-up hits for
  /// every existing customer.
  Future<void> _applyRemoteCreditCustomerUpdate(
    Map<String, dynamic> row,
  ) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.creditCustomers
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing == null) {
      await _applyRemoteCreditCustomerInsert(row);
      return;
    }

    final updated = creditCustomerFromRow(row)..id = existing.id;
    await _isar.writeTxn(() async {
      await _isar.creditCustomers.put(updated);
    });
    await _recomputeCreditBalance(uuid, row['store_id'] as String);
    _creditChangedController.add(null);
  }

  /// A customer deleted on another device. Postgres only guarantees a
  /// delete payload's `oldRecord` carries the primary key (`uuid`) - not
  /// the full row - so this can't reuse a row-mapper the way insert/update
  /// do. Mirrors CreditRepository.deleteCustomer's own local cleanup
  /// (customer + every transaction of theirs), just without re-enqueuing a
  /// sync event for a delete this device didn't initiate.
  Future<void> _applyRemoteCreditCustomerDelete(
    Map<String, dynamic> oldRow,
  ) async {
    final uuid = oldRow['uuid'] as String?;
    if (uuid == null) return;
    final existing = await _isar.creditCustomers
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing == null) return;

    await _isar.writeTxn(() async {
      final txIds = await _isar.creditTransactions
          .filter()
          .customerIdEqualTo(uuid)
          .idProperty()
          .findAll();
      if (txIds.isNotEmpty) {
        await _isar.creditTransactions.deleteAll(txIds);
      }
      await _isar.creditCustomers.delete(existing.id);
    });
    _creditChangedController.add(null);
    _customerDeletedController.add(uuid);
  }

  Future<void> _applyRemoteCreditTransaction(Map<String, dynamic> row) async {
    final inserted = await _insertCreditTransactionIfMissing(row);
    if (!inserted) return;
    await _recomputeCreditBalance(
      row['customer_id'] as String,
      row['store_id'] as String,
    );
    _creditChangedController.add(null);
  }

  Future<bool> _insertCreditTransactionIfMissing(
    Map<String, dynamic> row,
  ) async {
    final uuid = row['uuid'] as String;
    final existing = await _isar.creditTransactions
        .filter()
        .uuidEqualTo(uuid)
        .findFirst();
    if (existing != null) return false;
    await _isar.writeTxn(() async {
      await _isar.creditTransactions.put(creditTransactionFromRow(row));
    });
    return true;
  }

  /// Recomputes [customerUuid]'s outstanding balance directly from
  /// Supabase's full transaction history for them - not just whatever this
  /// device has caught up on locally, which could be incomplete (e.g. a
  /// customer this device only just learned about via catch-up/Realtime,
  /// before its own transaction history has necessarily arrived too) - and
  /// persists it locally, backfilling any transaction this device was
  /// missing along the way.
  ///
  /// `credit_customers.balance` is a running total mutated independently
  /// by whichever device performs an action (see [CreditRepository]) - two
  /// devices both applying their own delta to what they each locally
  /// believe the balance to be is exactly the kind of unordered-channel
  /// race `stock_events`/`initial_stock` already needed a structural fix
  /// for (see SCHEMA_TRUTH.md). `credit_transactions`, unlike
  /// `credit_customers.balance`, is insert-only and idempotent by uuid -
  /// recomputing from Supabase's full copy of it after every credit-related
  /// Realtime event (customer insert/update, or a new transaction) makes
  /// this device's local balance self-correcting regardless of arrival
  /// order, rather than trusting whatever snapshot happened to be baked
  /// into the most recently-applied `credit_customers` row. Found
  /// 2026-09-13: a second manual-credit add in a row updated transaction
  /// history but not the displayed balance on the other device.
  Future<void> _recomputeCreditBalance(
    String customerUuid,
    String storeId,
  ) async {
    try {
      final rows = await SupabaseService.supabaseClient
          .from('credit_transactions')
          .select()
          .eq('customer_id', customerUuid)
          .eq('store_id', storeId);
      for (final row in rows) {
        await _insertCreditTransactionIfMissing(row);
      }

      final transactions = await _isar.creditTransactions
          .filter()
          .customerIdEqualTo(customerUuid)
          .findAll();
      final recomputed = transactions.fold<double>(
        0,
        (sum, tx) => sum + creditTransactionSignedDelta(tx),
      );

      final customer = await _isar.creditCustomers
          .filter()
          .uuidEqualTo(customerUuid)
          .findFirst();
      if (customer == null || customer.balance == recomputed) return;
      customer.balance = recomputed;
      await _isar.writeTxn(() async {
        await _isar.creditCustomers.put(customer);
      });
    } catch (e) {
      // Best-effort - the balance stays whatever it was until the next
      // credit-related event triggers another recompute attempt.
      debugPrint('RealtimeDataSyncService: credit balance recompute failed: $e');
    }
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
    await _storeProfileChangedController.close();
    await _creditChangedController.close();
    await _productDeletedController.close();
    await _customerDeletedController.close();
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

/// Watched by the Settings screen to refresh when another device edits the
/// store profile.
final storeProfileChangedProvider = StreamProvider<void>((ref) {
  return ref.watch(realtimeDataSyncServiceProvider).storeProfileChanged;
});

/// Watched by the Customers list and Customer Detail to refresh when
/// another device adds/edits/deletes a customer or records a credit
/// transaction.
final creditChangedProvider = StreamProvider<void>((ref) {
  return ref.watch(realtimeDataSyncServiceProvider).creditChanged;
});

/// Watched by a currently-open product edit screen to navigate back if the
/// product it's editing is deleted on another device.
final productDeletedProvider = StreamProvider<String>((ref) {
  return ref.watch(realtimeDataSyncServiceProvider).productDeleted;
});

/// Watched by Customer Detail to navigate back if the customer it's
/// showing is deleted on another device.
final customerDeletedProvider = StreamProvider<String>((ref) {
  return ref.watch(realtimeDataSyncServiceProvider).customerDeleted;
});
