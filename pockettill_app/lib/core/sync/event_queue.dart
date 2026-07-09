import 'package:isar/isar.dart';

import '../../shared/models/sync_event.dart';

/// Isar-backed queue of [SyncEvent] records awaiting push to Supabase.
class EventQueue {
  EventQueue(this._isar);

  final Isar _isar;

  /// Persists [event] to the queue.
  Future<void> enqueue(SyncEvent event) async {
    await _isar.writeTxn(() async {
      await _isar.syncEvents.put(event);
    });
  }

  /// Returns all events not yet pushed, oldest first.
  Future<List<SyncEvent>> getPending() {
    return _isar.syncEvents
        .filter()
        .pushedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  /// Marks the events matching [uuids] as pushed.
  Future<void> markPushed(List<String> uuids) async {
    if (uuids.isEmpty) return;
    await _isar.writeTxn(() async {
      final events = await _isar.syncEvents
          .filter()
          .anyOf(uuids, (q, String uuid) => q.uuidEqualTo(uuid))
          .findAll();
      final now = DateTime.now();
      for (final event in events) {
        event.pushed = true;
        event.pushedAt = now;
      }
      await _isar.syncEvents.putAll(events);
    });
  }

  /// Number of events not yet pushed.
  Future<int> pendingCount() {
    return _isar.syncEvents.filter().pushedEqualTo(false).count();
  }
}
