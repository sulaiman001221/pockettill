import 'package:isar/isar.dart';

part 'credit_customer.g.dart';

@collection
class CreditCustomer {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String name;
  String? phone;
  late double balance; // running total owed
  double? creditLimit; // optional max amount this customer can owe
  bool synced = false;
  late DateTime createdAt;
  DateTime? lastActivityAt;
}
