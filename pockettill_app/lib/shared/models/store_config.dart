import 'package:isar/isar.dart';

part 'store_config.g.dart';

@collection
class StoreConfig {
  Id id = 1; // singleton — only one record ever

  late String storeId;
  late String storeName;
  late String deviceId;
  String? ownerPhone;
  DateTime? lastSyncedAt;
}
