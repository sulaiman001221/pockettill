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
  double? balanceBefore; // customer's balance immediately before this transaction
  double? balanceAfter; // customer's balance immediately after this transaction
  bool synced = false;
  late DateTime createdAt;
}
