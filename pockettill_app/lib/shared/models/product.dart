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
  // An Open Food Facts pull, the owner's own upload, or an auto-synced
  // PocketTill catalogue "enhanced" image - see add_product_screen.dart for
  // which wins when both exist, and ImageSyncService for the catalogue path.
  String? imageUrl;
  // Local on-device path to this product's cached, compressed (~50KB) copy
  // of [imageUrl] - see ImageCacheService. Never synced to Supabase (a
  // device-local file path is meaningless on another device); left stale
  // (pointing at an old image) whenever [imageUrl] changes until the cache
  // is refreshed, so always treat [imageUrl] as the source of truth for
  // *which* image this product has, and this only as *where it's cached*.
  String? cachedImagePath;
  bool synced = false;
  late DateTime createdAt;
  DateTime? updatedAt;
}
