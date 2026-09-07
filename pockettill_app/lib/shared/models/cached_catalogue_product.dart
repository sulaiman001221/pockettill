import 'package:isar/isar.dart';

part 'cached_catalogue_product.g.dart';

/// A local offline cache of a `catalogue_products` row, for Catalogue
/// Browse to work offline once a category/search has been fetched at least
/// once. Refreshed by pull-to-refresh, never by the regular sync cycle -
/// this isn't store-owned data being pushed/pulled like every other
/// collection, it's a read-only mirror of the shared, cross-store catalogue.
///
/// Deliberately NOT store-scoped and deliberately NOT cleared on store
/// switch/logout (see auth_service.dart's two local-data-clear blocks) -
/// the same catalogue applies to every store, so wiping it on switch would
/// just force a redundant re-fetch for no correctness benefit. If you're
/// here because a "new collection checklist" told you to check the
/// store-switch clear blocks: this collection is the intentional exception,
/// not a miss.
@collection
class CachedCatalogueProduct {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String barcode;

  late String name;
  String? mass;
  String? category;
  String? imageUrl;
  late DateTime cachedAt;
}
