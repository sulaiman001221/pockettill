import 'dart:convert';

import 'package:isar/isar.dart';

import '../../shared/models/sync_event.dart';

/// What this device has changed that the server hasn't confirmed yet, read
/// from the unpushed [SyncEvent] queue. The server owns every stock quantity
/// and credit balance, so a device shows `server value + its own unsent
/// changes` - never just its local running total.
class PendingChanges {
  PendingChanges._({
    required this.stockDelta,
    required this.balanceDelta,
    required this.unsentProductUuids,
    required this.unsentCustomerUuids,
    required this.deletedProductUuids,
    required this.deletedCustomerUuids,
    required this.createdProductUuids,
    required this.createdCustomerUuids,
    required this.createdExtraIncomeUuids,
  });

  /// Unsent stock change per product uuid (sales, returns, restocks and the
  /// stock part of a form edit).
  final Map<String, int> stockDelta;

  /// Unsent balance change per customer uuid, signed the same way the
  /// server's trigger signs it.
  final Map<String, double> balanceDelta;

  /// Products / customers with any unsent create, edit, image or delete -
  /// their fields must not be overwritten by an incoming server row.
  final Set<String> unsentProductUuids;
  final Set<String> unsentCustomerUuids;

  /// Products / customers deleted here but not yet deleted on the server -
  /// an incoming server row must not bring them back.
  final Set<String> deletedProductUuids;
  final Set<String> deletedCustomerUuids;

  /// Products / customers created here that the server hasn't seen yet.
  final Set<String> createdProductUuids;
  final Set<String> createdCustomerUuids;

  /// Extra-income entries created here that the server hasn't seen yet - an
  /// entry missing from a delete-reconciliation pass because it was only
  /// just created, not because another device deleted it.
  final Set<String> createdExtraIncomeUuids;

  static Future<PendingChanges> load(Isar isar) async {
    final pending = await isar.syncEvents
        .filter()
        .pushedEqualTo(false)
        .findAll();

    final stockDelta = <String, int>{};
    final balanceDelta = <String, double>{};
    final unsentProducts = <String>{};
    final unsentCustomers = <String>{};
    final deletedProducts = <String>{};
    final deletedCustomers = <String>{};
    final createdProducts = <String>{};
    final createdCustomers = <String>{};
    final createdExtraIncome = <String>{};

    for (final event in pending) {
      switch (event.entityType) {
        case 'stock_event':
          final payload = jsonDecode(event.payload) as Map<String, dynamic>;
          final productId = payload['product_id'] as String?;
          final delta = (payload['quantity_delta'] as num?)?.toInt() ?? 0;
          if (productId != null) {
            stockDelta[productId] = (stockDelta[productId] ?? 0) + delta;
          }
        case 'product':
          unsentProducts.add(event.entityUuid);
          if (event.operation == 'delete') deletedProducts.add(event.entityUuid);
          if (event.operation == 'create') createdProducts.add(event.entityUuid);
          final payload = jsonDecode(event.payload) as Map<String, dynamic>;
          final edit = payload['_edit'] as Map<String, dynamic>?;
          final editDelta = (edit?['stock_delta'] as num?)?.toInt() ?? 0;
          if (editDelta != 0) {
            stockDelta[event.entityUuid] =
                (stockDelta[event.entityUuid] ?? 0) + editDelta;
          }
        case 'credit_customer':
          unsentCustomers.add(event.entityUuid);
          if (event.operation == 'delete') {
            deletedCustomers.add(event.entityUuid);
          }
          if (event.operation == 'create') {
            createdCustomers.add(event.entityUuid);
          }
        case 'extra_income':
          if (event.operation == 'create') {
            createdExtraIncome.add(event.entityUuid);
          }
        case 'credit_tx':
          final payload = jsonDecode(event.payload) as Map<String, dynamic>;
          final customerId = payload['customer_id'] as String?;
          final amount = (payload['amount'] as num?)?.toDouble() ?? 0;
          if (customerId != null) {
            balanceDelta[customerId] =
                (balanceDelta[customerId] ?? 0) +
                signedBalanceDelta(payload['type'] as String?, amount);
          }
      }
    }

    return PendingChanges._(
      stockDelta: stockDelta,
      balanceDelta: balanceDelta,
      unsentProductUuids: unsentProducts,
      unsentCustomerUuids: unsentCustomers,
      deletedProductUuids: deletedProducts,
      deletedCustomerUuids: deletedCustomers,
      createdProductUuids: createdProducts,
      createdCustomerUuids: createdCustomers,
      createdExtraIncomeUuids: createdExtraIncome,
    );
  }

  /// How a credit transaction moves the customer's balance - must match the
  /// server's `apply_credit_tx_to_customer` trigger.
  static double signedBalanceDelta(String? type, double amount) {
    switch (type) {
      case 'repayment':
      case 'writeoff':
        return -amount;
      case 'purchase':
      case 'manual_credit':
      case 'return':
        return amount;
      default:
        return 0;
    }
  }
}
