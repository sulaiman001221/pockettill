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

    await _isar.writeTxn(() async {
      final customer = await _isar.creditCustomers
          .filter()
          .uuidEqualTo(customerUuid)
          .findFirst();
      if (customer == null) {
        throw StateError('Credit customer $customerUuid not found.');
      }

      customer.balance += amount;
      customer.lastActivityAt = now;
      await _isar.creditCustomers.put(customer);

      final transaction = CreditTransaction()
        ..uuid = _uuid.v4()
        ..customerId = customerUuid
        ..amount = amount
        ..type = 'purchase'
        ..saleUuid = saleUuid
        ..createdAt = now;
      await _isar.creditTransactions.put(transaction);

      await _enqueueEvent(
        entityType: 'credit_tx',
        entityUuid: transaction.uuid,
        operation: 'create',
        payload: _transactionToPayload(transaction),
      );
    });
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

      customer.balance -= amount;
      customer.lastActivityAt = now;
      await _isar.creditCustomers.put(customer);

      final transaction = CreditTransaction()
        ..uuid = _uuid.v4()
        ..customerId = customerUuid
        ..amount = amount
        ..type = 'repayment'
        ..note = note
        ..createdAt = now;
      await _isar.creditTransactions.put(transaction);

      await _enqueueEvent(
        entityType: 'credit_tx',
        entityUuid: transaction.uuid,
        operation: 'create',
        payload: _transactionToPayload(transaction),
      );
    });
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
    'createdAt': customer.createdAt.toIso8601String(),
    'lastActivityAt': customer.lastActivityAt?.toIso8601String(),
  };

  Map<String, dynamic> _transactionToPayload(CreditTransaction transaction) => {
    'uuid': transaction.uuid,
    'customerId': transaction.customerId,
    'amount': transaction.amount,
    'type': transaction.type,
    'saleUuid': transaction.saleUuid,
    'note': transaction.note,
    'createdAt': transaction.createdAt.toIso8601String(),
  };
}
