import 'package:isar/isar.dart';

part 'credit_transaction.g.dart';

@collection
class CreditTransaction {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String customerId;
  late double amount;
  late String type; // purchase | repayment
  String? saleUuid; // linked sale if type is purchase
  String? note;
  bool synced = false;
  late DateTime createdAt;
}
