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
  // The catalogue's enhanced-image URL last synced into [imageUrl] by
  // [ImageSyncService], if [imageUrl] currently *is* that synced-in image -
  // null otherwise (never synced one, or the owner has since replaced it
  // with their own photo). Lets a later sync tell "this image came from the
  // catalogue" apart from "the owner took this photo themselves", which is
  // what makes it possible to revert cleanly if the catalogue's enhancement
  // is later cleared with no replacement - see ImageSyncService.
  // Device-local bookkeeping only, never synced to Supabase (same as
  // [cachedImagePath] above - each device makes this call independently).
  String? catalogueSyncedImageUrl;
  bool synced = false;
  late DateTime createdAt;
  DateTime? updatedAt;
}
