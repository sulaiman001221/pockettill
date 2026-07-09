import 'package:isar/isar.dart';

part 'sale.g.dart';

@collection
class Sale {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String deviceId;
  late double total;
  late String paymentType; // cash | credit | card
  String? customerId; // populated if credit sale
  bool synced = false;
  late DateTime createdAt;
}
