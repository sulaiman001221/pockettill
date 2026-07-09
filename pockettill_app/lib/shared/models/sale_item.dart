import 'package:isar/isar.dart';

part 'sale_item.g.dart';

@collection
class SaleItem {
  Id id = Isar.autoIncrement;

  late String saleUuid;
  late String productUuid;
  late String productName; // snapshot at time of sale
  late double unitPrice; // snapshot at time of sale
  late int quantity;
  late double subtotal;
  bool synced = false;
}
