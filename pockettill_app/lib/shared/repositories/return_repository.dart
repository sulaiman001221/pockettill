import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../models/credit_customer.dart';
import '../models/credit_transaction.dart';
import '../models/product.dart';
import '../models/return_item.dart';
import '../models/return_record.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sync_event.dart';

/// Business logic for processing returns against past sales. Sits between
/// the UI and Isar - screens never touch Isar directly.
class ReturnRepository {
  ReturnRepository({required Isar isar}) : _isar = isar;

  final Isar _isar;
  final _uuid = const Uuid();

  /// Every return recorded against [saleUuid], most recent first.
  Future<List<ReturnRecord>> getForSale(String saleUuid) {
    return _isar.returnRecords
        .filter()
        .saleUuidEqualTo(saleUuid)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// The return matching [uuid], or null if none exists.
  Future<ReturnRecord?> getByUuid(String uuid) {
    return _isar.returnRecords.filter().uuidEqualTo(uuid).findFirst();
  }

  /// The [ReturnItem]s belonging to one specific return - unlike
  /// [getReturnedItemsForSale] (every return ever processed against a
  /// sale), this is scoped to a single return event, e.g. for
  /// ReturnDetailScreen's own line-item list.
  Future<List<ReturnItem>> getItemsForReturn(String returnUuid) {
    return _isar.returnItems.filter().returnUuidEqualTo(returnUuid).findAll();
  }

  /// All returns processed on [date]'s calendar day, newest first - mirrors
  /// [SaleRepository.getByDate] so Sales History can filter both the same
  /// way.
  Future<List<ReturnRecord>> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _isar.returnRecords
        .filter()
        .createdAtBetween(start, end, includeUpper: false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// All returns between [from] and [to], inclusive of both calendar days -
  /// mirrors [SaleRepository.getDateRange].
  Future<List<ReturnRecord>> getDateRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return _isar.returnRecords
        .filter()
        .createdAtBetween(start, end)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Every [ReturnItem] recorded against [saleUuid], across every return
  /// event processed for it.
  Future<List<ReturnItem>> getReturnedItemsForSale(String saleUuid) {
    return _isar.returnItems.filter().saleUuidEqualTo(saleUuid).findAll();
  }

  /// Total quantity already returned per product for [saleUuid] - each
  /// original [SaleItem]'s quantity minus this is how much of it is still
  /// returnable.
  Future<Map<String, int>> getReturnedQuantities(String saleUuid) async {
    final items = await getReturnedItemsForSale(saleUuid);
    final totals = <String, int>{};
    for (final item in items) {
      totals[item.productUuid] = (totals[item.productUuid] ?? 0) + item.quantity;
    }
    return totals;
  }

  /// Processes a return as one atomic operation: writes the [ReturnRecord]
  /// and its [ReturnItem]s, adjusts stock for each returned item per
  /// [stockAction] (skipped gracefully if a product was since deleted),
  /// decreases [exchangeProduct]'s stock for an exchange, adjusts a credit
  /// customer's balance for a refund-on-credit-sale or store credit, and
  /// enqueues sync events for everything - all within a single Isar
  /// transaction, the same pattern [SaleRepository.completeSale] uses for a
  /// sale's own multi-effect write.
  ///
  /// Each entry in [items] must be `{'saleItem': SaleItem, 'quantity': int}`.
  /// [customerId] is only meaningful (and required) when [resolutionType] is
  /// `refund` against a credit sale or `store_credit` - an exchange's cash
  /// difference never touches a credit balance, regardless of direction.
  Future<void> processReturn({
    required Sale sale,
    required List<Map<String, dynamic>> items,
    required String reason,
    required String stockAction,
    required String resolutionType,
    required double itemsValue,
    double customerOwes = 0,
    double customerReceives = 0,
    String? customerId,
    Product? exchangeProduct,
    required String deviceId,
  }) async {
    if (resolutionType == 'store_credit' && customerId == null) {
      throw ArgumentError('customerId is required for store credit.');
    }

    final returnUuid = _uuid.v4();
    final now = DateTime.now();

    final returnRecord = ReturnRecord()
      ..uuid = returnUuid
      ..saleUuid = sale.uuid
      ..deviceId = deviceId
      ..reason = reason
      ..stockAction = stockAction
      ..resolutionType = resolutionType
      ..itemsValue = itemsValue
      ..customerOwes = customerOwes
      ..customerReceives = customerReceives
      ..customerId = customerId
      ..exchangeProductUuid = exchangeProduct?.uuid
      ..exchangeProductName = exchangeProduct?.name
      ..createdAt = now;

    final returnItems = items.map((entry) {
      final saleItem = entry['saleItem'] as SaleItem;
      final quantity = entry['quantity'] as int;
      return ReturnItem()
        ..uuid = _uuid.v4()
        ..returnUuid = returnUuid
        ..saleUuid = sale.uuid
        ..productUuid = saleItem.productUuid
        ..productName = saleItem.productName
        ..unitPrice = saleItem.unitPrice
        ..quantity = quantity;
    }).toList();

    final events = <SyncEvent>[
      _buildEvent(
        entityType: 'return',
        entityUuid: returnUuid,
        operation: 'create',
        deviceId: deviceId,
        payload: _returnToPayload(returnRecord),
      ),
      for (final item in returnItems)
        _buildEvent(
          entityType: 'return_item',
          entityUuid: item.uuid,
          operation: 'create',
          deviceId: deviceId,
          payload: _returnItemToPayload(item),
        ),
    ];

    // Credit balance is only touched for a refund against a credit sale or
    // store credit - an exchange's cash difference is always settled at the
    // counter, never against a credit account.
    final touchesCreditBalance =
        (resolutionType == 'refund' || resolutionType == 'store_credit') &&
        customerId != null &&
        customerReceives > 0;

    await _isar.writeTxn(() async {
      await _isar.returnRecords.put(returnRecord);
      await _isar.returnItems.putAll(returnItems);

      if (stockAction == 'restock') {
        for (final item in returnItems) {
          final product = await _isar.products
              .filter()
              .uuidEqualTo(item.productUuid)
              .findFirst();
          // Gracefully skip if the product was deleted since the original
          // sale - the return itself is still recorded either way.
          if (product == null) continue;

          product.stock += item.quantity;
          product.updatedAt = now;
          await _isar.products.put(product);
          events.add(
            _buildEvent(
              entityType: 'product',
              entityUuid: product.uuid,
              operation: 'update',
              deviceId: deviceId,
              payload: _productToPayload(product),
            ),
          );
        }
      }
      // stockAction == 'write_off': nothing to adjust - the product is
      // damaged/unsellable, so its stock count is left untouched.

      if (exchangeProduct != null) {
        final product = await _isar.products
            .filter()
            .uuidEqualTo(exchangeProduct.uuid)
            .findFirst();
        if (product != null) {
          product.stock -= 1;
          product.updatedAt = now;
          await _isar.products.put(product);
          events.add(
            _buildEvent(
              entityType: 'product',
              entityUuid: product.uuid,
              operation: 'update',
              deviceId: deviceId,
              payload: _productToPayload(product),
            ),
          );
        }
      }

      if (touchesCreditBalance) {
        final customer = await _isar.creditCustomers
            .filter()
            .uuidEqualTo(customerId)
            .findFirst();
        if (customer == null) {
          throw StateError('Credit customer $customerId not found.');
        }

        final balanceBefore = customer.balance;
        customer.balance -= customerReceives;
        customer.lastActivityAt = now;
        await _isar.creditCustomers.put(customer);

        final transaction = CreditTransaction()
          ..uuid = _uuid.v4()
          ..customerId = customerId
          ..amount = customerReceives
          ..type = 'return'
          ..saleUuid = sale.uuid
          ..note = _reasonLabel(reason)
          ..balanceBefore = balanceBefore
          ..balanceAfter = customer.balance
          ..createdAt = now;
        await _isar.creditTransactions.put(transaction);
        events.add(
          _buildEvent(
            entityType: 'credit_tx',
            entityUuid: transaction.uuid,
            operation: 'create',
            deviceId: deviceId,
            payload: _transactionToPayload(transaction),
          ),
        );
      }

      await _isar.syncEvents.putAll(events);
    });
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'expired_broken':
        return 'Return - Expired or Broken';
      case 'wrong_item':
        return 'Return - Wrong Item';
      case 'change_of_mind':
        return 'Return - Change of Mind';
      default:
        return 'Return';
    }
  }

  SyncEvent _buildEvent({
    required String entityType,
    required String entityUuid,
    required String operation,
    required String deviceId,
    required Map<String, dynamic> payload,
  }) {
    return SyncEvent()
      ..uuid = _uuid.v4()
      ..entityType = entityType
      ..entityUuid = entityUuid
      ..operation = operation
      ..payload = jsonEncode(payload)
      ..deviceId = deviceId
      ..createdAt = DateTime.now();
  }

  Map<String, dynamic> _returnToPayload(ReturnRecord returnRecord) => {
    'uuid': returnRecord.uuid,
    'sale_uuid': returnRecord.saleUuid,
    'device_id': returnRecord.deviceId,
    'reason': returnRecord.reason,
    'stock_action': returnRecord.stockAction,
    'resolution_type': returnRecord.resolutionType,
    'items_value': returnRecord.itemsValue,
    'customer_owes': returnRecord.customerOwes,
    'customer_receives': returnRecord.customerReceives,
    'customer_id': returnRecord.customerId,
    'exchange_product_uuid': returnRecord.exchangeProductUuid,
    'exchange_product_name': returnRecord.exchangeProductName,
    'created_at': returnRecord.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _returnItemToPayload(ReturnItem item) => {
    'uuid': item.uuid,
    'return_uuid': item.returnUuid,
    'sale_uuid': item.saleUuid,
    'product_uuid': item.productUuid,
    'product_name': item.productName,
    'unit_price': item.unitPrice,
    'quantity': item.quantity,
  };

  Map<String, dynamic> _productToPayload(Product product) => {
    'uuid': product.uuid,
    'barcode': product.barcode,
    'name': product.name,
    'mass': product.mass,
    'category': product.category,
    'unit': product.unit,
    'price': product.price,
    'cost_price': product.costPrice,
    'stock': product.stock,
    'low_stock_threshold': product.lowStockThreshold,
    'is_verified': product.isVerified,
    'created_at': product.createdAt.toIso8601String(),
    'updated_at': product.updatedAt?.toIso8601String(),
  };

  Map<String, dynamic> _transactionToPayload(CreditTransaction transaction) => {
    'uuid': transaction.uuid,
    'customer_id': transaction.customerId,
    'amount': transaction.amount,
    'type': transaction.type,
    'sale_uuid': transaction.saleUuid,
    'note': transaction.note,
    'balance_before': transaction.balanceBefore,
    'balance_after': transaction.balanceAfter,
    'created_at': transaction.createdAt.toIso8601String(),
  };
}
