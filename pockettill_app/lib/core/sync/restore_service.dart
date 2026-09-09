import 'package:isar/isar.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/extra_income.dart';
import '../../shared/models/product.dart';
import '../../shared/models/return_item.dart';
import '../../shared/models/return_record.dart';
import '../../shared/models/risk_log.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../../shared/models/store_config.dart';
import '../supabase/supabase_service.dart';
import 'row_mappers.dart';

/// Re-hydrates a store's own products/sales/customers/returns from Supabase
/// into local Isar when the local cache is empty - the counterpart to
/// [AuthService]'s clear-on-store-switch: clearing has nowhere else to
/// recover from without this, and a fresh install or reinstall starts with
/// an empty local cache the same way. `SyncService` never does this itself -
/// it only pushes local changes and pulls the shared verified catalogue,
/// never a store's own past data.
///
/// Deliberately not merge/conflict-aware: only runs when local data looks
/// empty, so it never touches a device that already has real local rows.
class RestoreService {
  RestoreService({required Isar isar}) : _isar = isar;

  final Isar _isar;

  static const _pageSize = 500;

  /// Pulls [storeId]'s own history from Supabase into Isar, but only if the
  /// local cache looks empty - a no-op otherwise, so calling this on every
  /// login is safe and cheap for the common case (nothing to restore).
  Future<void> restoreIfEmpty(String storeId) async {
    final hasLocalData =
        await _isar.products.count() > 0 || await _isar.sales.count() > 0;
    if (hasLocalData) return;

    final products = await _fetchAll('products', storeId);
    // The `products.stock` column pulled above is only as fresh as the last
    // *manual* edit - a sale/return/manual adjustment updates it locally
    // via a stock_event delta, never by pushing the whole product row (see
    // ProductRepository.recordStockEvent). That means it can genuinely be
    // stale here, on a fresh install/reinstall pulling from Supabase for
    // the first time. stock_events is the actual authoritative ledger, so
    // recompute each product's real stock as the sum of its events instead
    // of trusting the column directly - the exact scenario
    // get_product_stock() exists for.
    final stockEventRows = await _fetchAll('stock_events', storeId);
    final stockByProduct = <String, int>{};
    DateTime? maxSyncedAt;
    for (final row in stockEventRows) {
      final productId = row['product_id'] as String;
      stockByProduct[productId] =
          (stockByProduct[productId] ?? 0) + (row['quantity_delta'] as int);
      final syncedAt = parseLocal(row['synced_at'] as String);
      if (maxSyncedAt == null || syncedAt.isAfter(maxSyncedAt)) {
        maxSyncedAt = syncedAt;
      }
    }

    final sales = await _fetchAll('sales', storeId);
    final saleItems = await _fetchAll('sale_items', storeId);
    final creditCustomers = await _fetchAll('credit_customers', storeId);
    final creditTransactions = await _fetchAll('credit_transactions', storeId);
    final returns = await _fetchAll('returns', storeId);
    final returnItems = await _fetchAll('return_items', storeId);
    final extraIncome = await _fetchAll('extra_income', storeId);
    final riskLog = await _fetchAll('risk_log', storeId);

    // A genuinely brand-new store with no history yet - nothing to write,
    // and an empty writeTxn would be pointless.
    if (products.isEmpty &&
        sales.isEmpty &&
        creditCustomers.isEmpty &&
        returns.isEmpty &&
        extraIncome.isEmpty &&
        riskLog.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      await _isar.products.putAll(
        products
            .map((row) => productFromRow(row, stockByProduct: stockByProduct))
            .toList(),
      );
      await _isar.sales.putAll(sales.map(saleFromRow).toList());
      await _isar.saleItems.putAll(saleItems.map(saleItemFromRow).toList());
      await _isar.creditCustomers.putAll(
        creditCustomers.map(creditCustomerFromRow).toList(),
      );
      await _isar.creditTransactions.putAll(
        creditTransactions.map(creditTransactionFromRow).toList(),
      );
      await _isar.returnRecords.putAll(
        returns.map(returnRecordFromRow).toList(),
      );
      await _isar.returnItems.putAll(
        returnItems.map(returnItemFromRow).toList(),
      );
      await _isar.extraIncomes.putAll(
        extraIncome.map(extraIncomeFromRow).toList(),
      );
      await _isar.riskLogs.putAll(riskLog.map(riskLogFromRow).toList());

      // High-water mark for RealtimeStockSyncService's reconnect catch-up
      // query - without this, the first catch-up after a fresh restore
      // would treat every event just summed above as "missed" and
      // needlessly re-fetch/re-apply all of them.
      if (maxSyncedAt != null) {
        final config = await _isar.storeConfigs.get(1);
        if (config != null) {
          config.lastStockEventSyncedAt = maxSyncedAt;
          await _isar.storeConfigs.put(config);
        }
      }
    });
  }

  /// Every row in [table] for [storeId], paginated - a real store's sales
  /// history alone can run into the thousands, well past Postgrest's default
  /// single-request row cap.
  Future<List<Map<String, dynamic>>> _fetchAll(
    String table,
    String storeId,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final page = await SupabaseService.supabaseClient
          .from(table)
          .select()
          .eq('store_id', storeId)
          .range(offset, offset + _pageSize - 1);
      rows.addAll(List<Map<String, dynamic>>.from(page));
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    return rows;
  }
}
