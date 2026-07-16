import 'package:isar/isar.dart';

part 'store_config.g.dart';

@collection
class StoreConfig {
  Id id = 1; // singleton — only one record ever

  late String storeId;
  late String storeName;
  late String deviceId;
  String? ownerName;
  String? ownerPhone;
  String? address;
  DateTime? lastSyncedAt;

  String? authUserId; // Supabase Auth user UUID
  String? authPhone; // formatted +27 phone used to register
  bool isBetaAdopter = false;
  bool isLoggedIn = false;
}
