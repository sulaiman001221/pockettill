import 'dart:async';
import 'dart:convert';

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
import '../database/isar_service.dart';
import '../storage/image_cache_service.dart';
import '../supabase/supabase_service.dart';
import 'pending_changes.dart';
import 'row_mappers.dart';
import 'server_row_applier.dart';
import 'sync_coordinator.dart';

/// Keeps this device's local copy of the store's data matching Supabase, the
/// single source of truth.
///
/// One code path does all the work: [pullNow] asks the server for anything
/// that changed since this device last looked (server-stamped `received_at`
/// for append-only tables, `updated_at` for products and customers, each
/// re-read with a short overlap and applied idempotently) and reconciles
/// deletions. Realtime is only a nudge - any change event on a table just
/// schedules a pull - and a periodic timer in main.dart pulls as well, so a
/// dropped socket, a backgrounded app or a missed message heals itself on
/// the next tick instead of leaving devices out of step until something else
/// happens to touch the same row.
///
/// Stock quantity and credit balance are never computed here: each device
/// shows the server's number plus its own not-yet-sent changes (see
/// [PendingChanges] and [ServerRowApplier]).
class RealtimeDataSyncService {
  RealtimeDataSyncService({required Isar isar})
    : _isar = isar,
      _applier = ServerRowApplier(isar);

  final Isar _isar;
  final ServerRowApplier _applier;
  final List<RealtimeChannel> _channels = [];

  static const _pageSize = 500;

  /// Every pull re-reads this far behind its cursor. Rows are stamped with
  /// the server's transaction start time, so one that committed late can
  /// carry a slightly older stamp than a row already seen.
  static const _overlap = Duration(minutes: 2);

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

  /// A remote sale/return/extra-income entry was applied locally.
  Stream<void> get salesChanged => _salesChangedController.stream;

  /// A remote risk_log entry was applied locally.
  Stream<void> get riskLogChanged => _riskLogChangedController.stream;

  /// A product was created, edited, restocked/sold elsewhere (stock is part
  /// of the product row) or deleted.
  Stream<void> get productsChanged => _productsChangedController.stream;

  /// Another device's Settings edit was applied locally.
  Stream<void> get storeProfileChanged => _storeProfileChangedController.stream;

  /// A customer or credit transaction changed.
  Stream<void> get creditChanged => _creditChangedController.stream;

  /// A product deleted elsewhere was removed locally - lets an open edit
  /// screen for it close instead of editing a row that no longer exists.
  Stream<String> get productDeleted => _productDeletedController.stream;

  /// A customer deleted elsewhere was removed locally.
  Stream<String> get customerDeleted => _customerDeletedController.stream;

  bool _starting = false;
  bool _pulling = false;
  bool _pullAgain = false;
  Timer? _debounce;

  /// Opens the realtime nudge channels, then pulls. A no-op if already
  /// subscribed or if there's no logged-in store.
  Future<void> start() async {
    if (_channels.isNotEmpty || _starting) return;
    _starting = true;

    try {
      final storeConfig = await _isar.storeConfigs.get(1);
      if (storeConfig == null ||
          !storeConfig.isLoggedIn ||
          storeConfig.storeId.isEmpty) {
        return;
      }
      final storeId = storeConfig.storeId;

      // A restored session can still hold an expired access token for a
      // moment on launch; channels joined with it are rejected outright
      // (InvalidJWTToken) and stay dead until something reconnects them.
      final auth = SupabaseService.supabaseClient.auth;
      final session = auth.currentSession;
      if (session != null && session.isExpired) {
        try {
          await auth.refreshSession();
        } catch (e) {
          debugPrint('RealtimeDataSyncService: session refresh failed: $e');
        }
      }

      _channels.addAll([
        for (final table in const [
          'sales',
          'sale_items',
          'returns',
          'return_items',
          'risk_log',
          'extra_income',
          'credit_transactions',
        ])
          _subscribe(
            table: table,
            event: PostgresChangeEvent.insert,
            storeId: storeId,
          ),
        for (final table in const ['products', 'credit_customers']) ...[
          _subscribe(
            table: table,
            event: PostgresChangeEvent.insert,
            storeId: storeId,
          ),
          _subscribe(
            table: table,
            event: PostgresChangeEvent.update,
            storeId: storeId,
          ),
          // A delete payload only carries the primary key, so it can't be
          // filtered by store server-side (and RLS already limits what this
          // client can see to its own store). The pull's reconciliation is
          // what actually removes the row.
          _subscribe(
            table: table,
            event: PostgresChangeEvent.delete,
            storeId: storeId,
            filtered: false,
          ),
        ],
        // stores has no store_id column - its own primary key is the id.
        _subscribe(
          table: 'stores',
          event: PostgresChangeEvent.update,
          storeId: storeId,
          filterColumn: 'uuid',
        ),
      ]);

      await pullNow();
    } catch (e) {
      debugPrint('RealtimeDataSyncService.start() failed: $e');
    } finally {
      _starting = false;
    }
  }

  /// Closes every channel - call when connectivity drops. [start] re-opens
  /// them (and pulls) on the next reconnect.
  Future<void> stop() async {
    _debounce?.cancel();
    final channels = List<RealtimeChannel>.from(_channels);
    _channels.clear();
    for (final channel in channels) {
      await SupabaseService.supabaseClient.removeChannel(channel);
    }
  }

  RealtimeChannel _subscribe({
    required String table,
    required PostgresChangeEvent event,
    required String storeId,
    String filterColumn = 'store_id',
    bool filtered = true,
  }) {
    final channel = SupabaseService.supabaseClient.channel(
      '$table:$storeId:${event.name}',
    );
    channel
        .onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          filter: filtered
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: filterColumn,
                  value: storeId,
                )
              : null,
          callback: (_) => _requestPull(),
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint(
              'RealtimeDataSyncService: $table ${event.name} channel '
              'error=$error',
            );
          }
        });
    return channel;
  }

  /// Several realtime events usually arrive together (a sale touches sales,
  /// sale_items, products...), so wait a moment and pull once.
  void _requestPull() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(pullNow());
    });
  }

  /// Pulls everything that changed on the server since this device last
  /// looked. Safe to call at any time and from anywhere: overlapping calls
  /// collapse into one more run after the current one.
  Future<void> pullNow() async {
    if (_pulling) {
      _pullAgain = true;
      return;
    }
    _pulling = true;
    try {
      do {
        _pullAgain = false;
        await _pullOnce();
      } while (_pullAgain);
    } catch (e, st) {
      debugPrint('RealtimeDataSyncService.pullNow() failed: $e\n$st');
    } finally {
      _pulling = false;
    }
  }

  Future<void> _pullOnce() async {
    // Never pull in the middle of a push - see SyncCoordinator.
    for (var i = 0; i < 40 && SyncCoordinator.pushInFlight; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final config = await _isar.storeConfigs.get(1);
    if (config == null || !config.isLoggedIn || config.storeId.isEmpty) return;
    final storeId = config.storeId;
    final cursors = _readCursors(config.syncCursors);

    Future<void> pull({
      required String table,
      required String column,
      required List<String> orderBy,
      required Future<bool> Function(List<Map<String, dynamic>> rows) apply,
      required void Function() onChanged,
    }) async {
      try {
        var anyChanged = false;
        final newest = await _pullTable(
          table: table,
          storeId: storeId,
          column: column,
          orderBy: orderBy,
          cursor: cursors[table],
          apply: (rows) async {
            if (await apply(rows)) anyChanged = true;
          },
        );
        if (newest != null) cursors[table] = newest;
        if (anyChanged) onChanged();
      } catch (e) {
        // One table failing must not stop the others; its cursor doesn't
        // move, so the next pull retries the same range.
        debugPrint('RealtimeDataSyncService: pull of $table failed: $e');
      }
    }

    // Customers before their transactions, products before nothing that
    // depends on them here - order only matters for tidy UI refreshes.
    await pull(
      table: 'products',
      column: 'updated_at',
      orderBy: const ['uuid'],
      apply: (rows) async => await _applier.applyProducts(rows) > 0,
      onChanged: () => _productsChangedController.add(null),
    );
    await pull(
      table: 'credit_customers',
      column: 'updated_at',
      orderBy: const ['uuid'],
      apply: (rows) async => await _applier.applyCustomers(rows) > 0,
      onChanged: () => _creditChangedController.add(null),
    );
    await pull(
      table: 'credit_transactions',
      column: 'received_at',
      orderBy: const ['uuid'],
      apply: (rows) => _eachRow(rows, _applyCreditTransaction),
      onChanged: () => _creditChangedController.add(null),
    );
    await pull(
      table: 'sales',
      column: 'received_at',
      orderBy: const ['uuid'],
      apply: (rows) => _eachRow(rows, _applySale),
      onChanged: () => _salesChangedController.add(null),
    );
    await pull(
      table: 'sale_items',
      column: 'received_at',
      orderBy: const ['sale_uuid', 'product_uuid'],
      apply: (rows) => _eachRow(rows, _applySaleItem),
      onChanged: () {},
    );
    await pull(
      table: 'returns',
      column: 'received_at',
      orderBy: const ['uuid'],
      apply: (rows) => _eachRow(rows, _applyReturn),
      onChanged: () => _salesChangedController.add(null),
    );
    await pull(
      table: 'return_items',
      column: 'received_at',
      orderBy: const ['uuid'],
      apply: (rows) => _eachRow(rows, _applyReturnItem),
      onChanged: () {},
    );
    await pull(
      table: 'extra_income',
      column: 'received_at',
      orderBy: const ['uuid'],
      apply: (rows) => _eachRow(rows, _applyExtraIncome),
      onChanged: () => _salesChangedController.add(null),
    );
    await pull(
      table: 'risk_log',
      column: 'received_at',
      orderBy: const ['uuid'],
      apply: (rows) => _eachRow(rows, _applyRiskLog),
      onChanged: () => _riskLogChangedController.add(null),
    );

    await _reconcileProductDeletes(storeId);
    await _reconcileCustomerDeletes(storeId);
    await _pullStoreProfile(storeId);

    await _saveCursors(cursors);
  }

  Future<bool> _eachRow(
    List<Map<String, dynamic>> rows,
    Future<bool> Function(Map<String, dynamic> row) apply,
  ) async {
    var any = false;
    for (final row in rows) {
      if (await apply(row)) any = true;
    }
    return any;
  }

  // -- cursors --------------------------------------------------------------

  Map<String, String> _readCursors(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCursors(Map<String, String> cursors) async {
    await _isar.writeTxn(() async {
      final config = await _isar.storeConfigs.get(1);
      if (config == null) return;
      config.syncCursors = jsonEncode(cursors);
      await _isar.storeConfigs.put(config);
    });
  }

  /// Pages through every row of [table] changed since [cursor] (everything,
  /// the first time) and returns the newest [column] value seen, or the old
  /// cursor if there was nothing newer.
  Future<String?> _pullTable({
    required String table,
    required String storeId,
    required String column,
    required List<String> orderBy,
    required String? cursor,
    required Future<void> Function(List<Map<String, dynamic>> rows) apply,
  }) async {
    final since = cursor == null
        ? null
        : DateTime.parse(cursor).subtract(_overlap).toUtc().toIso8601String();
    DateTime? newest = cursor == null ? null : DateTime.parse(cursor);
    var offset = 0;

    while (true) {
      var filter = SupabaseService.supabaseClient
          .from(table)
          .select()
          .eq('store_id', storeId);
      if (since != null) filter = filter.gte(column, since);
      var query = filter.order(column);
      for (final key in orderBy) {
        query = query.order(key);
      }
      final page = await query.range(offset, offset + _pageSize - 1);

      await apply(page);
      for (final row in page) {
        final stamp = row[column] as String?;
        if (stamp != null) {
          final parsed = DateTime.parse(stamp);
          if (newest == null || parsed.isAfter(newest)) newest = parsed;
        }
      }
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }

    return newest?.toUtc().toIso8601String();
  }

  // -- deletions -------------------------------------------------------------

  /// A product this device still has but the server no longer does was
  /// deleted elsewhere. Never touches one created here that hasn't reached
  /// the server yet.
  Future<void> _reconcileProductDeletes(String storeId) async {
    try {
      // Local list first, server list second: a product created between the
      // two isn't in the local snapshot, so can't be mistaken for deleted.
      final localUuids = (await _isar.products.where().findAll())
          .map((p) => p.uuid)
          .toSet();
      final remoteRows = await SupabaseService.supabaseClient
          .from('products')
          .select('uuid')
          .eq('store_id', storeId);
      final remoteUuids = remoteRows.map((r) => r['uuid'] as String).toSet();
      if (remoteUuids.isEmpty && localUuids.length > 1) return;

      for (final uuid in localUuids.difference(remoteUuids)) {
        String? cacheKey;
        final removed = await _isar.writeTxn(() async {
          final pending = await PendingChanges.load(_isar);
          if (pending.createdProductUuids.contains(uuid)) return false;
          final product = await _isar.products
              .filter()
              .uuidEqualTo(uuid)
              .findFirst();
          if (product == null) return false;
          cacheKey = product.barcode;
          final eventIds = await _isar.stockEvents
              .filter()
              .productUuidEqualTo(uuid)
              .idProperty()
              .findAll();
          if (eventIds.isNotEmpty) await _isar.stockEvents.deleteAll(eventIds);
          await _isar.products.delete(product.id);
          return true;
        });
        if (!removed) continue;
        final key = cacheKey;
        if (key != null) await ImageCacheService.deleteCachedFile(key);
        _productsChangedController.add(null);
        _productDeletedController.add(uuid);
      }
    } catch (e) {
      debugPrint('RealtimeDataSyncService: product delete reconcile failed: $e');
    }
  }

  Future<void> _reconcileCustomerDeletes(String storeId) async {
    try {
      final localUuids = (await _isar.creditCustomers.where().findAll())
          .map((c) => c.uuid)
          .toSet();
      final remoteRows = await SupabaseService.supabaseClient
          .from('credit_customers')
          .select('uuid')
          .eq('store_id', storeId);
      final remoteUuids = remoteRows.map((r) => r['uuid'] as String).toSet();
      if (remoteUuids.isEmpty && localUuids.length > 1) return;

      for (final uuid in localUuids.difference(remoteUuids)) {
        final removed = await _isar.writeTxn(() async {
          final pending = await PendingChanges.load(_isar);
          if (pending.createdCustomerUuids.contains(uuid)) return false;
          final customer = await _isar.creditCustomers
              .filter()
              .uuidEqualTo(uuid)
              .findFirst();
          if (customer == null) return false;
          final txIds = await _isar.creditTransactions
              .filter()
              .customerIdEqualTo(uuid)
              .idProperty()
              .findAll();
          if (txIds.isNotEmpty) await _isar.creditTransactions.deleteAll(txIds);
          await _isar.creditCustomers.delete(customer.id);
          return true;
        });
        if (!removed) continue;
        _creditChangedController.add(null);
        _customerDeletedController.add(uuid);
      }
    } catch (e) {
      debugPrint('RealtimeDataSyncService: customer delete reconcile failed: $e');
    }
  }

  // -- append-only rows (idempotent by uuid) ---------------------------------

  Future<bool> _applySale(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    if (await _isar.sales.filter().uuidEqualTo(uuid).findFirst() != null) {
      return false;
    }
    await _isar.writeTxn(() async {
      await _isar.sales.put(saleFromRow(row));
    });
    return true;
  }

  Future<bool> _applySaleItem(Map<String, dynamic> row) async {
    final existing = await _isar.saleItems
        .filter()
        .saleUuidEqualTo(row['sale_uuid'] as String)
        .and()
        .productUuidEqualTo(row['product_uuid'] as String)
        .findFirst();
    if (existing != null) return false;
    await _isar.writeTxn(() async {
      await _isar.saleItems.put(saleItemFromRow(row));
    });
    return true;
  }

  Future<bool> _applyReturn(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    if (await _isar.returnRecords.filter().uuidEqualTo(uuid).findFirst() !=
        null) {
      return false;
    }
    await _isar.writeTxn(() async {
      await _isar.returnRecords.put(returnRecordFromRow(row));
    });
    return true;
  }

  Future<bool> _applyReturnItem(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    if (await _isar.returnItems.filter().uuidEqualTo(uuid).findFirst() !=
        null) {
      return false;
    }
    await _isar.writeTxn(() async {
      await _isar.returnItems.put(returnItemFromRow(row));
    });
    return true;
  }

  Future<bool> _applyRiskLog(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    if (await _isar.riskLogs.filter().uuidEqualTo(uuid).findFirst() != null) {
      return false;
    }
    await _isar.writeTxn(() async {
      await _isar.riskLogs.put(riskLogFromRow(row));
    });
    return true;
  }

  Future<bool> _applyExtraIncome(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    if (await _isar.extraIncomes.filter().uuidEqualTo(uuid).findFirst() !=
        null) {
      return false;
    }
    await _isar.writeTxn(() async {
      await _isar.extraIncomes.put(extraIncomeFromRow(row));
    });
    return true;
  }

  Future<bool> _applyCreditTransaction(Map<String, dynamic> row) async {
    final uuid = row['uuid'] as String;
    if (await _isar.creditTransactions.filter().uuidEqualTo(uuid).findFirst() !=
        null) {
      return false;
    }
    await _isar.writeTxn(() async {
      await _isar.creditTransactions.put(creditTransactionFromRow(row));
    });
    return true;
  }

  // -- store profile ---------------------------------------------------------

  /// Another device's Settings edit (store name, owner name/phone, address,
  /// or the Product Images toggles). Only touches the profile fields
  /// `_enqueueStoreProfileSync` actually pushes, never this device's own
  /// local-only state, and skips the write and the signal entirely when
  /// nothing changed - `stores` is also updated for unrelated reasons (the
  /// founding-store check stamps it on every call), and signalling on every
  /// such change once created a genuine refresh loop in Settings.
  Future<void> _pullStoreProfile(String storeId) async {
    try {
      final rows = await SupabaseService.supabaseClient
          .from('stores')
          .select()
          .eq('uuid', storeId);
      if (rows.isEmpty) return;
      final row = rows.first;

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
    } catch (e) {
      debugPrint('RealtimeDataSyncService: store profile pull failed: $e');
    }
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

/// Watched by Stock to refresh when a product changes anywhere - stock
/// quantity included, since that's part of the product row now.
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
