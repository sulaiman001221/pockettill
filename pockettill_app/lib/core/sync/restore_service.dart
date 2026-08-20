import 'package:isar/isar.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/extra_income.dart';
import '../../shared/models/product.dart';
import '../../shared/models/return_item.dart';
import '../../shared/models/return_record.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';
import '../supabase/supabase_service.dart';

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
    final sales = await _fetchAll('sales', storeId);
    final saleItems = await _fetchAll('sale_items', storeId);
    final creditCustomers = await _fetchAll('credit_customers', storeId);
    final creditTransactions = await _fetchAll('credit_transactions', storeId);
    final returns = await _fetchAll('returns', storeId);
    final returnItems = await _fetchAll('return_items', storeId);
    final extraIncome = await _fetchAll('extra_income', storeId);

    // A genuinely brand-new store with no history yet - nothing to write,
    // and an empty writeTxn would be pointless.
    if (products.isEmpty &&
        sales.isEmpty &&
        creditCustomers.isEmpty &&
        returns.isEmpty &&
        extraIncome.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      await _isar.products.putAll(products.map(_productFromRow).toList());
      await _isar.sales.putAll(sales.map(_saleFromRow).toList());
      await _isar.saleItems.putAll(saleItems.map(_saleItemFromRow).toList());
      await _isar.creditCustomers.putAll(
        creditCustomers.map(_creditCustomerFromRow).toList(),
      );
      await _isar.creditTransactions.putAll(
        creditTransactions.map(_creditTransactionFromRow).toList(),
      );
      await _isar.returnRecords.putAll(
        returns.map(_returnRecordFromRow).toList(),
      );
      await _isar.returnItems.putAll(
        returnItems.map(_returnItemFromRow).toList(),
      );
      await _isar.extraIncomes.putAll(
        extraIncome.map(_extraIncomeFromRow).toList(),
      );
    });
  }

  /// Parses a Postgrest timestamptz string (always UTC on the wire) back to
  /// a local [DateTime] - every other DateTime in this app is local (built
  /// via `DateTime.now()`), so a restored row must match that convention or
  /// it silently drifts by this device's UTC offset against "today"/"this
  /// week" comparisons elsewhere in the app.
  DateTime _parseLocal(String value) => DateTime.parse(value).toLocal();

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

  Product _productFromRow(Map<String, dynamic> row) => Product()
    ..uuid = row['uuid'] as String
    ..barcode = row['barcode'] as String
    ..name = row['name'] as String
    ..mass = row['mass'] as String?
    ..category = row['category'] as String?
    ..unit = row['unit'] as String?
    ..price = (row['price'] as num).toDouble()
    ..costPrice = (row['cost_price'] as num?)?.toDouble()
    ..stock = row['stock'] as int
    ..lowStockThreshold = row['low_stock_threshold'] as int? ?? 5
    ..synced = true
    ..createdAt = _parseLocal(row['created_at'] as String)
    ..updatedAt = row['updated_at'] != null
        ? _parseLocal(row['updated_at'] as String)
        : null;

  Sale _saleFromRow(Map<String, dynamic> row) => Sale()
    ..uuid = row['uuid'] as String
    ..deviceId = row['device_id'] as String
    ..total = (row['total'] as num).toDouble()
    ..paymentType = row['payment_type'] as String
    ..customerId = row['customer_id'] as String?
    ..synced = true
    ..createdAt = _parseLocal(row['created_at'] as String);

  SaleItem _saleItemFromRow(Map<String, dynamic> row) => SaleItem()
    ..saleUuid = row['sale_uuid'] as String
    ..productUuid = row['product_uuid'] as String
    ..productName = row['product_name'] as String
    ..unitPrice = (row['unit_price'] as num).toDouble()
    ..quantity = row['quantity'] as int
    ..subtotal = (row['subtotal'] as num).toDouble()
    ..synced = true;

  CreditCustomer _creditCustomerFromRow(Map<String, dynamic> row) =>
      CreditCustomer()
        ..uuid = row['uuid'] as String
        ..name = row['name'] as String
        ..phone = row['phone'] as String?
        ..balance = (row['balance'] as num).toDouble()
        ..creditLimit = (row['credit_limit'] as num?)?.toDouble()
        ..synced = true
        ..createdAt = _parseLocal(row['created_at'] as String)
        ..lastActivityAt = row['last_activity_at'] != null
            ? _parseLocal(row['last_activity_at'] as String)
            : null;

  CreditTransaction _creditTransactionFromRow(Map<String, dynamic> row) =>
      CreditTransaction()
        ..uuid = row['uuid'] as String
        ..customerId = row['customer_id'] as String
        ..amount = (row['amount'] as num).toDouble()
        ..type = row['type'] as String
        ..saleUuid = row['sale_uuid'] as String?
        ..note = row['note'] as String?
        ..balanceBefore = (row['balance_before'] as num?)?.toDouble()
        ..balanceAfter = (row['balance_after'] as num?)?.toDouble()
        ..synced = true
        ..createdAt = _parseLocal(row['created_at'] as String);

  ReturnRecord _returnRecordFromRow(Map<String, dynamic> row) =>
      ReturnRecord()
        ..uuid = row['uuid'] as String
        ..saleUuid = row['sale_uuid'] as String
        ..deviceId = row['device_id'] as String
        ..reason = row['reason'] as String
        ..stockAction = row['stock_action'] as String
        ..resolutionType = row['resolution_type'] as String
        ..itemsValue = (row['items_value'] as num).toDouble()
        ..customerOwes = (row['customer_owes'] as num?)?.toDouble() ?? 0
        ..customerReceives =
            (row['customer_receives'] as num?)?.toDouble() ?? 0
        ..cashPaidToCustomer =
            (row['cash_paid_to_customer'] as num?)?.toDouble() ?? 0
        ..customerId = row['customer_id'] as String?
        ..exchangeProductUuid = row['exchange_product_uuid'] as String?
        ..exchangeProductName = row['exchange_product_name'] as String?
        ..synced = true
        ..createdAt = _parseLocal(row['created_at'] as String);

  ReturnItem _returnItemFromRow(Map<String, dynamic> row) => ReturnItem()
    ..uuid = row['uuid'] as String
    ..returnUuid = row['return_uuid'] as String
    ..saleUuid = row['sale_uuid'] as String
    ..productUuid = row['product_uuid'] as String
    ..productName = row['product_name'] as String
    ..unitPrice = (row['unit_price'] as num).toDouble()
    ..quantity = row['quantity'] as int
    ..synced = true;

  ExtraIncome _extraIncomeFromRow(Map<String, dynamic> row) => ExtraIncome()
    ..uuid = row['uuid'] as String
    ..amount = (row['amount'] as num).toDouble()
    ..description = row['description'] as String
    ..synced = true
    ..createdAt = _parseLocal(row['created_at'] as String);
}
