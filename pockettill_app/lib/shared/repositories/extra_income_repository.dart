import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/event_queue.dart';
import '../models/extra_income.dart';
import '../models/store_config.dart';
import '../models/sync_event.dart';

/// Business logic for one-off extra income entries (airtime, electricity
/// tokens, etc.) that aren't regular sales. Sits between the UI and Isar -
/// screens never touch Isar directly.
class ExtraIncomeRepository {
  ExtraIncomeRepository({required Isar isar, required EventQueue eventQueue})
    : _isar = isar,
      _eventQueue = eventQueue;

  final Isar _isar;
  final EventQueue _eventQueue;
  final _uuid = const Uuid();

  /// All entries on [date]'s calendar day, newest first - mirrors
  /// SaleRepository.getByDate.
  Future<List<ExtraIncome>> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _isar.extraIncomes
        .filter()
        .createdAtBetween(start, end, includeUpper: false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// All entries between [from] and [to], inclusive of both calendar days -
  /// mirrors SaleRepository.getDateRange.
  Future<List<ExtraIncome>> getDateRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return _isar.extraIncomes
        .filter()
        .createdAtBetween(start, end)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Records a new extra income entry and enqueues a sync event. [date] is
  /// the calendar day picked in the form (today by default); combined with
  /// the current time-of-day so entries from the same day still sort
  /// sensibly against each other and against same-day sales.
  Future<void> add({
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final entry = ExtraIncome()
      ..uuid = _uuid.v4()
      ..amount = amount
      ..description = description
      ..createdAt = DateTime(
        date.year,
        date.month,
        date.day,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
      );

    await _isar.writeTxn(() async {
      await _isar.extraIncomes.put(entry);
    });

    await _enqueueEvent(entry, operation: 'create');
  }

  /// Looks up a single entry by its uuid, or null if it doesn't exist (e.g.
  /// already deleted from another device).
  Future<ExtraIncome?> getByUuid(String uuid) {
    return _isar.extraIncomes.filter().uuidEqualTo(uuid).findFirst();
  }

  /// Updates an existing entry's amount/description/date and enqueues a
  /// sync event. Only the calendar day of [date] is applied - the original
  /// time-of-day is preserved so the entry's relative order among same-day
  /// entries/sales doesn't jump around just because it was edited later.
  Future<void> update({
    required String uuid,
    required double amount,
    required String description,
    required DateTime date,
  }) async {
    final entry = await getByUuid(uuid);
    if (entry == null) return;

    entry
      ..amount = amount
      ..description = description
      ..createdAt = DateTime(
        date.year,
        date.month,
        date.day,
        entry.createdAt.hour,
        entry.createdAt.minute,
        entry.createdAt.second,
        entry.createdAt.millisecond,
      );

    await _isar.writeTxn(() async {
      await _isar.extraIncomes.put(entry);
    });

    await _enqueueEvent(entry, operation: 'update');
  }

  /// Deletes an entry outright.
  Future<void> delete(String uuid) async {
    final entry = await getByUuid(uuid);
    if (entry == null) return;

    await _isar.writeTxn(() async {
      await _isar.extraIncomes.delete(entry.id);
    });

    await _enqueueEvent(entry, operation: 'delete');
  }

  Future<void> _enqueueEvent(
    ExtraIncome entry, {
    required String operation,
  }) async {
    final deviceId = (await _isar.storeConfigs.get(1))?.deviceId ?? '';
    final event = SyncEvent()
      ..uuid = _uuid.v4()
      ..entityType = 'extra_income'
      ..entityUuid = entry.uuid
      ..operation = operation
      ..payload = jsonEncode(_toPayload(entry))
      ..deviceId = deviceId
      ..createdAt = DateTime.now();
    await _eventQueue.enqueue(event);
  }

  Map<String, dynamic> _toPayload(ExtraIncome entry) => {
    'uuid': entry.uuid,
    'amount': entry.amount,
    'description': entry.description,
    'created_at': entry.createdAt.toUtc().toIso8601String(),
  };
}
