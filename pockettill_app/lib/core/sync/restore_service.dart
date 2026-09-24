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

    // products.stock is the server's authoritative quantity (kept by the
    // stock_events trigger), so a restored product just takes it as is.
    final products = await _fetchAll('products', storeId);

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

    // The "is local empty?" check above happens before the (slow) fetches,
    // and the normal pull path can insert the very same rows while they run.
    // uuid has no unique index, so a blind putAll then created a second copy
    // of every row (a whole store's products showing twice after switching
    // accounts, reported 2026-09-24). Re-check inside the write transaction,
    // which serializes against the pull's own writes, and skip anything
    // already there.
    await _isar.writeTxn(() async {
      Future<List<T>> onlyNew<T>(
        Iterable<T> incoming,
        String Function(T) uuidOf,
        Future<List<T>> Function() loadLocal,
      ) async {
        final have = (await loadLocal()).map(uuidOf).toSet();
        return incoming.where((row) => !have.contains(uuidOf(row))).toList();
      }

      await _isar.products.putAll(
        await onlyNew(
          products.map(productFromRow),
          (p) => p.uuid,
          () => _isar.products.where().findAll(),
        ),
      );
      final newSales = await onlyNew(
        sales.map(saleFromRow),
        (s) => s.uuid,
        () => _isar.sales.where().findAll(),
      );
      await _isar.sales.putAll(newSales);
      // Sale items have no uuid of their own - they belong to whichever
      // sales were just inserted here; items of a sale that already existed
      // locally are already there too.
      final newSaleUuids = newSales.map((s) => s.uuid).toSet();
      await _isar.saleItems.putAll(
        saleItems
            .map(saleItemFromRow)
            .where((item) => newSaleUuids.contains(item.saleUuid))
            .toList(),
      );
      await _isar.creditCustomers.putAll(
        await onlyNew(
          creditCustomers.map(creditCustomerFromRow),
          (c) => c.uuid,
          () => _isar.creditCustomers.where().findAll(),
        ),
      );
      await _isar.creditTransactions.putAll(
        await onlyNew(
          creditTransactions.map(creditTransactionFromRow),
          (t) => t.uuid,
          () => _isar.creditTransactions.where().findAll(),
        ),
      );
      await _isar.returnRecords.putAll(
        await onlyNew(
          returns.map(returnRecordFromRow),
          (r) => r.uuid,
          () => _isar.returnRecords.where().findAll(),
        ),
      );
      await _isar.returnItems.putAll(
        await onlyNew(
          returnItems.map(returnItemFromRow),
          (r) => r.uuid,
          () => _isar.returnItems.where().findAll(),
        ),
      );
      await _isar.extraIncomes.putAll(
        await onlyNew(
          extraIncome.map(extraIncomeFromRow),
          (e) => e.uuid,
          () => _isar.extraIncomes.where().findAll(),
        ),
      );
      await _isar.riskLogs.putAll(
        await onlyNew(
          riskLog.map(riskLogFromRow),
          (r) => r.uuid,
          () => _isar.riskLogs.where().findAll(),
        ),
      );
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
