import 'package:isar/isar.dart';

part 'return_item.g.dart';

/// One product line within a [ReturnRecord]. Unlike [SaleItem] (one row per
/// product per sale, ever), a single (saleUuid, productUuid) pair can appear
/// across several ReturnItem rows over time - a sale can be partially
/// returned more than once - so this needs its own uuid rather than reusing
/// that composite key.
@collection
class ReturnItem {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String returnUuid;
  late String saleUuid;

  // Copied from the original SaleItem, so always known - whether the live
  // Product row still exists is a separate question, handled gracefully at
  // stock-adjustment time (productName/unitPrice below are a snapshot
  // either way, so the return stays fully readable if it doesn't).
  late String productUuid;
  late String productName;
  late double unitPrice;
  late int quantity;

  bool synced = false;
}
