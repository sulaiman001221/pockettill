import 'package:isar/isar.dart';

part 'sync_event.g.dart';

@collection
class SyncEvent {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String entityType; // sale | product | credit_customer | credit_tx
  late String entityUuid;
  late String operation; // create | update | delete
  late String payload; // JSON string of the full entity
  late String deviceId;
  late DateTime createdAt;
  bool pushed = false;
  DateTime? pushedAt;
}
