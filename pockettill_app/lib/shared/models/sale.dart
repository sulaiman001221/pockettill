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
  // Only set for a cash sale - the physical amount handed over, so change
  // (cashReceived - total) can be shown later on Sale Detail. Two devices
  // recording sales offline have no other way to reconcile a cash
  // discrepancy after the fact without this - see SaleDetailScreen.
  double? cashReceived;
  bool synced = false;
  late DateTime createdAt;
}
