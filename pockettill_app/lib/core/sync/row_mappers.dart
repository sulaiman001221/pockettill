import '../../shared/models/credit_customer.dart';
import '../../shared/models/credit_transaction.dart';
import '../../shared/models/extra_income.dart';
import '../../shared/models/product.dart';
import '../../shared/models/return_item.dart';
import '../../shared/models/return_record.dart';
import '../../shared/models/risk_log.dart';
import '../../shared/models/sale.dart';
import '../../shared/models/sale_item.dart';

/// Row-to-model mappers for a Postgrest/Realtime row straight off Supabase -
/// shared by [RestoreService] (a device's own full history pull) and
/// [RealtimeDataSyncService] (another device's row arriving live), so the
/// two don't drift into two different ideas of what a `sales` row means.
///
/// Every timestamp column comes across the wire as a UTC ISO string -
/// [parseLocal] converts it to a local [DateTime], matching every other
/// DateTime in this app (built via `DateTime.now()`), so a row from either
/// path doesn't silently drift by this device's UTC offset against
/// "today"/"this week" comparisons elsewhere in the app.
DateTime parseLocal(String value) => DateTime.parse(value).toLocal();

/// [stockByProduct], if given (keyed by `products.uuid`), is the sum of
/// every `stock_events` delta for that product - the authoritative current
/// stock, used in place of the possibly-stale `stock` column whenever this
/// product has at least one event (see [RestoreService]'s full-history
/// pull, which computes this once for every product it's restoring).
/// Omitted (null) when mapping a single row for [RealtimeDataSyncService] -
/// there, the row's own `stock` column is trusted directly, which is safe
/// specifically for a brand-new product this device has never seen before:
/// whatever `stock_events` the creating device already recorded for it get
/// marked "seen" (not reapplied) by [RealtimeStockSyncService] the moment
/// they arrive, whether that's before or after this row itself does, so
/// there's no double-count risk the way there would be for reapplying
/// history to a product this device already has its own running total for.
Product productFromRow(
  Map<String, dynamic> row, {
  Map<String, int>? stockByProduct,
}) => Product()
  ..uuid = row['uuid'] as String
  ..barcode = row['barcode'] as String
  ..name = row['name'] as String
  ..mass = row['mass'] as String?
  ..category = row['category'] as String?
  ..unit = row['unit'] as String?
  ..price = (row['price'] as num).toDouble()
  ..costPrice = (row['cost_price'] as num?)?.toDouble()
  ..stock = stockByProduct?[row['uuid'] as String] ?? row['stock'] as int
  ..lowStockThreshold = row['low_stock_threshold'] as int? ?? 5
  ..imageUrl = row['image_url'] as String?
  ..synced = true
  ..createdAt = parseLocal(row['created_at'] as String)
  ..updatedAt = row['updated_at'] != null
      ? parseLocal(row['updated_at'] as String)
      : null;

Sale saleFromRow(Map<String, dynamic> row) => Sale()
  ..uuid = row['uuid'] as String
  ..deviceId = row['device_id'] as String
  ..total = (row['total'] as num).toDouble()
  ..paymentType = row['payment_type'] as String
  ..customerId = row['customer_id'] as String?
  ..cashReceived = (row['cash_received'] as num?)?.toDouble()
  ..synced = true
  ..createdAt = parseLocal(row['created_at'] as String);

SaleItem saleItemFromRow(Map<String, dynamic> row) => SaleItem()
  ..saleUuid = row['sale_uuid'] as String
  ..productUuid = row['product_uuid'] as String
  ..productName = row['product_name'] as String
  ..unitPrice = (row['unit_price'] as num).toDouble()
  ..quantity = row['quantity'] as int
  ..subtotal = (row['subtotal'] as num).toDouble()
  ..synced = true;

CreditCustomer creditCustomerFromRow(Map<String, dynamic> row) =>
    CreditCustomer()
      ..uuid = row['uuid'] as String
      ..name = row['name'] as String
      ..phone = row['phone'] as String?
      ..balance = (row['balance'] as num).toDouble()
      ..creditLimit = (row['credit_limit'] as num?)?.toDouble()
      ..synced = true
      ..createdAt = parseLocal(row['created_at'] as String)
      ..lastActivityAt = row['last_activity_at'] != null
          ? parseLocal(row['last_activity_at'] as String)
          : null;

CreditTransaction creditTransactionFromRow(Map<String, dynamic> row) =>
    CreditTransaction()
      ..uuid = row['uuid'] as String
      ..customerId = row['customer_id'] as String
      ..amount = (row['amount'] as num).toDouble()
      ..type = row['type'] as String
      ..saleUuid = row['sale_uuid'] as String?
      ..note = row['note'] as String?
      ..balanceBefore = (row['balance_before'] as num?)?.toDouble()
      ..balanceAfter = (row['balance_after'] as num?)?.toDouble()
      ..cashReceived = (row['cash_received'] as num?)?.toDouble()
      ..synced = true
      ..createdAt = parseLocal(row['created_at'] as String);

ReturnRecord returnRecordFromRow(Map<String, dynamic> row) => ReturnRecord()
  ..uuid = row['uuid'] as String
  ..saleUuid = row['sale_uuid'] as String
  ..deviceId = row['device_id'] as String
  ..reason = row['reason'] as String
  ..stockAction = row['stock_action'] as String
  ..resolutionType = row['resolution_type'] as String
  ..itemsValue = (row['items_value'] as num).toDouble()
  ..customerOwes = (row['customer_owes'] as num?)?.toDouble() ?? 0
  ..customerReceives = (row['customer_receives'] as num?)?.toDouble() ?? 0
  ..cashPaidToCustomer =
      (row['cash_paid_to_customer'] as num?)?.toDouble() ?? 0
  ..customerId = row['customer_id'] as String?
  ..exchangeProductUuid = row['exchange_product_uuid'] as String?
  ..exchangeProductName = row['exchange_product_name'] as String?
  ..synced = true
  ..createdAt = parseLocal(row['created_at'] as String);

ReturnItem returnItemFromRow(Map<String, dynamic> row) => ReturnItem()
  ..uuid = row['uuid'] as String
  ..returnUuid = row['return_uuid'] as String
  ..saleUuid = row['sale_uuid'] as String
  ..productUuid = row['product_uuid'] as String
  ..productName = row['product_name'] as String
  ..unitPrice = (row['unit_price'] as num).toDouble()
  ..quantity = row['quantity'] as int
  ..synced = true;

ExtraIncome extraIncomeFromRow(Map<String, dynamic> row) => ExtraIncome()
  ..uuid = row['uuid'] as String
  ..amount = (row['amount'] as num).toDouble()
  ..description = row['description'] as String
  ..synced = true
  ..createdAt = parseLocal(row['created_at'] as String);

RiskLog riskLogFromRow(Map<String, dynamic> row) => RiskLog()
  ..uuid = row['uuid'] as String
  ..type = row['type'] as String
  ..description = row['description'] as String
  ..beforeValue = row['before_value'] as String?
  ..afterValue = row['after_value'] as String?
  ..entityName = row['entity_name'] as String
  ..synced = true
  ..timestamp = parseLocal(row['created_at'] as String);
