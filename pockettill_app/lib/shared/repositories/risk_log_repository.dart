import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../core/sync/event_queue.dart';
import '../models/risk_log.dart';
import '../models/store_config.dart';
import '../models/sync_event.dart';

/// Records potentially suspicious stock/credit activity for the Risk Log
/// screen - see [RiskLog]'s own doc comment for the fixed set of [record]'s
/// `type` values. Write-only from the rest of the app's perspective:
/// nothing ever edits or deletes an entry once recorded.
class RiskLogRepository {
  RiskLogRepository({required Isar isar, required EventQueue eventQueue})
    : _isar = isar,
      _eventQueue = eventQueue;

  final Isar _isar;
  final EventQueue _eventQueue;
  final _uuid = const Uuid();

  /// Records one risk event. [beforeValue]/[afterValue] are freeform
  /// display strings (e.g. `'12'` -> `'3'` for a stock reduction, `'R15.00'`
  /// -> `'R25.00'` for a price change) - whatever reads naturally on the
  /// Risk Log screen, not necessarily raw numbers.
  Future<void> record({
    required String type,
    required String description,
    String? beforeValue,
    String? afterValue,
    required String entityName,
  }) async {
    final entry = RiskLog()
      ..uuid = _uuid.v4()
      ..type = type
      ..description = description
      ..beforeValue = beforeValue
      ..afterValue = afterValue
      ..entityName = entityName
      ..timestamp = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.riskLogs.put(entry);
    });

    final deviceId = (await _isar.storeConfigs.get(1))?.deviceId ?? '';
    final event = SyncEvent()
      ..uuid = _uuid.v4()
      ..entityType = 'risk_log'
      ..entityUuid = entry.uuid
      ..operation = 'create'
      ..payload = jsonEncode(_toPayload(entry))
      ..deviceId = deviceId
      ..createdAt = DateTime.now();
    await _eventQueue.enqueue(event);
  }

  /// All entries on [date]'s calendar day, newest first - mirrors
  /// SaleRepository.getByDate / ExtraIncomeRepository.getByDate.
  Future<List<RiskLog>> getByDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _isar.riskLogs
        .filter()
        .timestampBetween(start, end, includeUpper: false)
        .sortByTimestampDesc()
        .findAll();
  }

  /// All entries between [from] and [to], inclusive of both calendar days -
  /// mirrors SaleRepository.getDateRange.
  Future<List<RiskLog>> getDateRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return _isar.riskLogs
        .filter()
        .timestampBetween(start, end)
        .sortByTimestampDesc()
        .findAll();
  }

  Map<String, dynamic> _toPayload(RiskLog entry) => {
    'uuid': entry.uuid,
    'type': entry.type,
    'description': entry.description,
    'before_value': entry.beforeValue,
    'after_value': entry.afterValue,
    'entity_name': entry.entityName,
    'created_at': entry.timestamp.toUtc().toIso8601String(),
  };
}
