import 'package:isar/isar.dart';

part 'product.g.dart';

@collection
class Product {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String barcode;
  late String name;
  String? mass; // optional, e.g. "2L", "500g" - keeps naming consistent
  String? category;
  String? unit; // each | kg | litre
  late double price;
  double? costPrice; // optional, for margin tracking
  late int stock;
  int lowStockThreshold = 5;
  bool isVerified = false;
  bool synced = false;
  late DateTime createdAt;
  DateTime? updatedAt;
}
