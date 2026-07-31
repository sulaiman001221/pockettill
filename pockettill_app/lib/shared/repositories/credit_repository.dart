import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/event_queue.dart';
import '../models/credit_customer.dart';
import '../models/credit_transaction.dart';
import '../models/store_config.dart';
import '../models/sync_event.dart';

/// Business logic for credit/tab customers and their transactions. Sits
/// between the UI and Isar - screens never touch Isar directly.
class CreditRepository {
  CreditRepository({required Isar isar, required EventQueue eventQueue})
    : _isar = isar,
      _eventQueue = eventQueue;

  final Isar _isar;
  final EventQueue _eventQueue;
  final _uuid = const Uuid();

  /// All credit customers, ordered by name ascending.
  Future<List<CreditCustomer>> getAll() {
    return _isar.creditCustomers.where().sortByName().findAll();
  }

  /// Customers with an outstanding balance whose last activity was more
  /// than [days] days ago (or who have never had any activity).
  Future<List<CreditCustomer>> getOverdue({int days = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _isar.creditCustomers
        .filter()
        .balanceGreaterThan(0)
        .and()
        .group(
          (q) => q.lastActivityAtLessThan(cutoff).or().lastActivityAtIsNull(),
        )
        .findAll();
  }

  /// The customer matching [uuid], or null if none exists.
  Future<CreditCustomer?> getByUuid(String uuid) {
    return _isar.creditCustomers.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Sum of every customer's outstanding balance.
  Future<double> getTotalOutstanding() async {
    final all = await _isar.creditCustomers.where().findAll();
    return all.fold<double>(0, (sum, customer) => sum + customer.balance);
  }

  /// Writes [customer] to Isar and enqueues a sync event.
  ///
  /// Looks up any existing row by [CreditCustomer.uuid] first: if found,
  /// this is an update (the existing Isar [Id] is reused so `put` replaces
  /// the row instead of inserting a duplicate, and [CreditCustomer.createdAt]
  /// is preserved); otherwise a uuid is generated if needed and this is a
  /// create.
  Future<void> saveCustomer(CreditCustomer customer) async {
    // An empty uuid always means "not yet created" - never match it against
    // another row (a stray empty-uuid row in the data would otherwise get
    // silently overwritten by every subsequent new customer).
    final existing = customer.uuid.isEmpty
        ? null
        : await _isar.creditCustomers
              .filter()
              .uuidEqualTo(customer.uuid)
              .findFirst();
    final isNew = existing == null;
    final now = DateTime.now();

    if (isNew) {
      if (customer.uuid.isEmpty) {
        customer.uuid = _uuid.v4();
      }
      customer.createdAt = now;
    } else {
      customer.id = existing.id;
      customer.createdAt = existing.createdAt;
    }

    await _isar.writeTxn(() async {
      await _isar.creditCustomers.put(customer);
    });

    await _enqueueEvent(
      entityType: 'credit_customer',
      entityUuid: customer.uuid,
      operation: isNew ? 'create' : 'update',
      payload: _customerToPayload(customer),
    );
  }

  /// Records a credit purchase: creates a `purchase` [CreditTransaction],
  /// increases the customer's balance, and stamps their last activity time.
  Future<void> addPurchase({
    required String customerUuid,
    required double amount,
    required String saleUuid,
  }) async {
    final now = DateTime.now();
    late final CreditTransaction transaction;

    await _isar.writeTxn(() async {
      final customer = await _isar.creditCustomers
          .filter()
          .uuidEqualTo(customerUuid)
          .findFirst();
      if (customer == null) {
        throw StateError('Credit customer $customerUuid not found.');
      }

      final balanceBefore = customer.balance;
      customer.balance += amount;
      customer.lastActivityAt = now;
      await _isar.creditCustomers.put(customer);

      transaction = CreditTransaction()
        ..uuid = _uuid.v4()
        ..customerId = customerUuid
        ..amount = amount
        ..type = 'purchase'
        ..saleUuid = saleUuid
        ..balanceBefore = balanceBefore
        ..balanceAfter = customer.balance
        ..createdAt = now;
      await _isar.creditTransactions.put(transaction);
    });

    // Isar doesn't support nested transactions - EventQueue.enqueue opens
    // its own writeTxn, so this must run after the one above has closed.
    await _enqueueEvent(
      entityType: 'credit_tx',
      entityUuid: transaction.uuid,
      operation: 'create',
      payload: _transactionToPayload(transaction),
    );
  }

  /// Records a repayment against a customer's balance. Throws if [amount]
  /// exceeds the current outstanding balance - balance can never go
  /// negative.
  Future<void> recordRepayment({
    required String customerUuid,
    required double amount,
    String? note,
  }) async {
    final now = DateTime.now();
    late final CreditTransaction transaction;

    await _isar.writeTxn(() async {
      final customer = await _isar.creditCustomers
          .filter()
          .uuidEqualTo(customerUuid)
          .findFirst();
      if (customer == null) {
        throw StateError('Credit customer $customerUuid not found.');
      }
      if (amount > customer.balance) {
        throw ArgumentError(
          'Repayment of $amount exceeds outstanding balance of ${customer.balance}.',
        );
      }

      final balanceBefore = customer.balance;
      customer.balance -= amount;
      customer.lastActivityAt = now;
      await _isar.creditCustomers.put(customer);

      transaction = CreditTransaction()
        ..uuid = _uuid.v4()
        ..customerId = customerUuid
        ..amount = amount
        ..type = 'repayment'
        ..note = note
        ..balanceBefore = balanceBefore
        ..balanceAfter = customer.balance
        ..createdAt = now;
      await _isar.creditTransactions.put(transaction);
    });

    // Isar doesn't support nested transactions - EventQueue.enqueue opens
    // its own writeTxn, so this must run after the one above has closed.
    await _enqueueEvent(
      entityType: 'credit_tx',
      entityUuid: transaction.uuid,
      operation: 'create',
      payload: _transactionToPayload(transaction),
    );
  }

  /// Updates just a customer's credit limit (null clears it).
  Future<void> updateCreditLimit(String customerUuid, double? creditLimit) async {
    final customer = await getByUuid(customerUuid);
    if (customer == null) return;

    customer.creditLimit = creditLimit;

    await _isar.writeTxn(() async {
      await _isar.creditCustomers.put(customer);
    });

    await _enqueueEvent(
      entityType: 'credit_customer',
      entityUuid: customer.uuid,
      operation: 'update',
      payload: _customerToPayload(customer),
    );
  }

  /// Deletes a customer outright, along with their transaction history.
  Future<void> deleteCustomer(String customerUuid) async {
    final customer = await getByUuid(customerUuid);
    if (customer == null) return;

    await _isar.writeTxn(() async {
      final txIds = await _isar.creditTransactions
          .filter()
          .customerIdEqualTo(customerUuid)
          .idProperty()
          .findAll();
      if (txIds.isNotEmpty) {
        await _isar.creditTransactions.deleteAll(txIds);
      }
      await _isar.creditCustomers.delete(customer.id);
    });

    await _enqueueEvent(
      entityType: 'credit_customer',
      entityUuid: customer.uuid,
      operation: 'delete',
      payload: _customerToPayload(customer),
    );
  }

  /// Transactions for [customerUuid], newest first.
  Future<List<CreditTransaction>> getTransactionsForCustomer(
    String customerUuid, {
    int limit = 50,
  }) {
    return _isar.creditTransactions
        .filter()
        .customerIdEqualTo(customerUuid)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  /// Every repayment (cash collected from a debtor, across all customers)
  /// recorded between [from] and [to], inclusive of both calendar days -
  /// used for Sales History's summary breakdown and the end-of-day
  /// reconciliation.
  Future<List<CreditTransaction>> getRepaymentsInRange(
    DateTime from,
    DateTime to,
  ) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return _isar.creditTransactions
        .filter()
        .typeEqualTo('repayment')
        .createdAtBetween(start, end)
        .findAll();
  }

  Future<void> _enqueueEvent({
    required String entityType,
    required String entityUuid,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final deviceId = (await _isar.storeConfigs.get(1))?.deviceId ?? '';
    final event = SyncEvent()
      ..uuid = _uuid.v4()
      ..entityType = entityType
      ..entityUuid = entityUuid
      ..operation = operation
      ..payload = jsonEncode(payload)
      ..deviceId = deviceId
      ..createdAt = DateTime.now();
    await _eventQueue.enqueue(event);
  }

  Map<String, dynamic> _customerToPayload(CreditCustomer customer) => {
    'uuid': customer.uuid,
    'name': customer.name,
    'phone': customer.phone,
    'balance': customer.balance,
    'credit_limit': customer.creditLimit,
    'created_at': customer.createdAt.toIso8601String(),
    'last_activity_at': customer.lastActivityAt?.toIso8601String(),
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
