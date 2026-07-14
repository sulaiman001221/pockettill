import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../models/credit_customer.dart';
import '../models/credit_transaction.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/sync_event.dart';

/// Business logic for sales and sale line items, plus the daily/weekly
/// analytics derived from them. Sits between the UI and Isar - screens never
/// touch Isar directly.
class SaleRepository {
  SaleRepository({required Isar isar}) : _isar = isar;

  final Isar _isar;
  final _uuid = const Uuid();

  /// Sales newest first, paginated.
  Future<List<Sale>> getAll({int limit = 50, int offset = 0}) {
    return _isar.sales
        .where()
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  /// All sales on [date]'s calendar day, newest first.
  Future<List<Sale>> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _isar.sales
        .filter()
        .createdAtBetween(start, end, includeUpper: false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Sales between [from] and [to], inclusive of both calendar days.
  Future<List<Sale>> getDateRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return _isar.sales
        .filter()
        .createdAtBetween(start, end)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// The sale matching [uuid], or null if none exists.
  Future<Sale?> getByUuid(String uuid) {
    return _isar.sales.filter().uuidEqualTo(uuid).findFirst();
  }

  /// All line items belonging to [saleUuid].
  Future<List<SaleItem>> getItemsForSale(String saleUuid) {
    return _isar.saleItems.filter().saleUuidEqualTo(saleUuid).findAll();
  }

  /// Completes a sale: writes the [Sale] and its [SaleItem]s, adjusts stock
  /// for each product sold, updates the customer's credit balance if this is
  /// a credit sale, and enqueues sync events for the sale and its items -
  /// all within a single Isar transaction (Isar transactions are reentrant,
  /// so the nested writes from [ProductRepository.adjustStock],
  /// [CreditRepository.addPurchase], and [EventQueue.enqueue] all join this
  /// same transaction rather than starting new ones).
  ///
  /// Each entry in [cartItems] must be a map of `{'product': Product,
  /// 'quantity': int}`.
  Future<void> completeSale({
    required List<Map<String, dynamic>> cartItems,
    required String paymentType,
    String? customerId,
    required String deviceId,
  }) async {
    if (paymentType == 'credit' && customerId == null) {
      throw ArgumentError('customerId is required for credit sales.');
    }

    final saleUuid = _uuid.v4();
    final now = DateTime.now();

    var total = 0.0;
    for (final item in cartItems) {
      final product = item['product'] as Product;
      final quantity = item['quantity'] as int;
      total += product.price * quantity;
    }

    final sale = Sale()
      ..uuid = saleUuid
      ..deviceId = deviceId
      ..total = total
      ..paymentType = paymentType
      ..customerId = customerId
      ..createdAt = now;

    final saleItems = cartItems.map((item) {
      final product = item['product'] as Product;
      final quantity = item['quantity'] as int;
      return SaleItem()
        ..saleUuid = saleUuid
        ..productUuid = product.uuid
        ..productName = product.name
        ..unitPrice = product.price
        ..quantity = quantity
        ..subtotal = product.price * quantity;
    }).toList();

    final events = <SyncEvent>[
      _buildEvent(
        entityType: 'sale',
        entityUuid: saleUuid,
        operation: 'create',
        deviceId: deviceId,
        payload: _saleToPayload(sale),
      ),
      for (final item in saleItems)
        _buildEvent(
          entityType: 'sale_item',
          entityUuid: '${item.saleUuid}:${item.productUuid}',
          operation: 'create',
          deviceId: deviceId,
          payload: _saleItemToPayload(item),
        ),
    ];

    // Isar doesn't support nested write transactions, so every write this
    // sale needs - the sale, its line items, stock adjustments, the credit
    // ledger, and the sync events - happens directly here in one
    // transaction, rather than through repository methods that would each
    // try to open their own.
    await _isar.writeTxn(() async {
      await _isar.sales.put(sale);
      await _isar.saleItems.putAll(saleItems);

      for (final item in cartItems) {
        final product = item['product'] as Product;
        final quantity = item['quantity'] as int;
        product.stock -= quantity;
        product.updatedAt = now;
        await _isar.products.put(product);
      }

      if (paymentType == 'credit') {
        final customer = await _isar.creditCustomers
            .filter()
            .uuidEqualTo(customerId!)
            .findFirst();
        if (customer == null) {
          throw StateError('Credit customer $customerId not found.');
        }

        customer.balance += total;
        customer.lastActivityAt = now;
        await _isar.creditCustomers.put(customer);

        final transaction = CreditTransaction()
          ..uuid = _uuid.v4()
          ..customerId = customerId
          ..amount = total
          ..type = 'purchase'
          ..saleUuid = saleUuid
          ..createdAt = now;
        await _isar.creditTransactions.put(transaction);

        events.add(
          _buildEvent(
            entityType: 'credit_tx',
            entityUuid: transaction.uuid,
            operation: 'create',
            deviceId: deviceId,
            payload: _creditTransactionToPayload(transaction),
          ),
        );
      }

      await _isar.syncEvents.putAll(events);
    });
  }

  /// Today's headline numbers: totals, transaction count, best seller, and
  /// the cash/credit/card split.
  Future<Map<String, dynamic>> getTodaySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final todaySales = await _isar.sales
        .filter()
        .createdAtBetween(start, end, includeUpper: false)
        .findAll();

    final totalSales = todaySales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );

    var cashTotal = 0.0;
    var creditTotal = 0.0;
    var cardTotal = 0.0;
    for (final sale in todaySales) {
      switch (sale.paymentType) {
        case 'cash':
          cashTotal += sale.total;
        case 'credit':
          creditTotal += sale.total;
        case 'card':
          cardTotal += sale.total;
      }
    }

    String? topProductName;
    int? topProductQuantity;
    final saleUuids = todaySales.map((sale) => sale.uuid).toSet();

    if (saleUuids.isNotEmpty) {
      final items = await _isar.saleItems
          .filter()
          .anyOf(saleUuids, (q, String uuid) => q.saleUuidEqualTo(uuid))
          .findAll();

      final quantityByProduct = <String, int>{};
      final nameByProduct = <String, String>{};
      for (final item in items) {
        quantityByProduct[item.productUuid] =
            (quantityByProduct[item.productUuid] ?? 0) + item.quantity;
        nameByProduct[item.productUuid] = item.productName;
      }

      if (quantityByProduct.isNotEmpty) {
        final topEntry = quantityByProduct.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        topProductName = nameByProduct[topEntry.key];
        topProductQuantity = topEntry.value;
      }
    }

    return {
      'totalSales': totalSales,
      'transactionCount': todaySales.length,
      'topProductName': topProductName,
      'topProductQuantity': topProductQuantity,
      'cashTotal': cashTotal,
      'creditTotal': creditTotal,
      'cardTotal': cardTotal,
    };
  }

  /// Daily totals for today and the previous 6 days.
  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final results = <Map<String, dynamic>>[];

    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      final sales = await _isar.sales
          .filter()
          .createdAtBetween(day, nextDay, includeUpper: false)
          .findAll();

      results.add({
        'date': day,
        'total': sales.fold<double>(0, (sum, sale) => sum + sale.total),
        'transactionCount': sales.length,
      });
    }

    return results;
  }

  /// Top 10 products by quantity sold in the last [days] days.
  Future<List<Map<String, dynamic>>> getTopProducts({int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final recentSales = await _isar.sales
        .filter()
        .createdAtGreaterThan(cutoff)
        .findAll();
    final saleUuids = recentSales.map((sale) => sale.uuid).toSet();

    if (saleUuids.isEmpty) return [];

    final items = await _isar.saleItems
        .filter()
        .anyOf(saleUuids, (q, String uuid) => q.saleUuidEqualTo(uuid))
        .findAll();

    final quantityByProduct = <String, int>{};
    final revenueByProduct = <String, double>{};
    final nameByProduct = <String, String>{};

    for (final item in items) {
      quantityByProduct[item.productUuid] =
          (quantityByProduct[item.productUuid] ?? 0) + item.quantity;
      revenueByProduct[item.productUuid] =
          (revenueByProduct[item.productUuid] ?? 0) + item.subtotal;
      nameByProduct[item.productUuid] = item.productName;
    }

    final ranked = quantityByProduct.keys.toList()
      ..sort(
        (a, b) => quantityByProduct[b]!.compareTo(quantityByProduct[a]!),
      );

    return ranked
        .take(10)
        .map(
          (productUuid) => {
            'productUuid': productUuid,
            'productName': nameByProduct[productUuid],
            'quantitySold': quantityByProduct[productUuid],
            'revenue': revenueByProduct[productUuid],
          },
        )
        .toList();
  }

  /// Percentage split of revenue across cash/credit/card in the last [days]
  /// days.
  Future<Map<String, double>> getPaymentSplit({int days = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final sales = await _isar.sales
        .filter()
        .createdAtGreaterThan(cutoff)
        .findAll();

    var cash = 0.0;
    var credit = 0.0;
    var card = 0.0;
    for (final sale in sales) {
      switch (sale.paymentType) {
        case 'cash':
          cash += sale.total;
        case 'credit':
          credit += sale.total;
        case 'card':
          card += sale.total;
      }
    }

    final total = cash + credit + card;
    if (total == 0) {
      return {'cash': 0, 'credit': 0, 'card': 0};
    }

    return {
      'cash': (cash / total) * 100,
      'credit': (credit / total) * 100,
      'card': (card / total) * 100,
    };
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

  Map<String, dynamic> _saleToPayload(Sale sale) => {
    'uuid': sale.uuid,
    'device_id': sale.deviceId,
    'total': sale.total,
    'payment_type': sale.paymentType,
    'customer_id': sale.customerId,
    'created_at': sale.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _saleItemToPayload(SaleItem item) => {
    'sale_uuid': item.saleUuid,
    'product_uuid': item.productUuid,
    'product_name': item.productName,
    'unit_price': item.unitPrice,
    'quantity': item.quantity,
    'subtotal': item.subtotal,
  };

  Map<String, dynamic> _creditTransactionToPayload(
    CreditTransaction transaction,
  ) => {
    'uuid': transaction.uuid,
    'customer_id': transaction.customerId,
    'amount': transaction.amount,
    'type': transaction.type,
    'sale_uuid': transaction.saleUuid,
    'note': transaction.note,
    'created_at': transaction.createdAt.toIso8601String(),
  };
}
