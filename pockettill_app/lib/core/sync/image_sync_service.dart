import 'dart:async';
import 'dart:io';

import 'package:isar/isar.dart';

import '../../shared/models/product.dart';
import '../../shared/models/store_config.dart';
import '../../shared/repositories/product_repository.dart';
import '../storage/image_cache_service.dart';
import '../supabase/supabase_service.dart';

/// Auto-syncs a store's product photos with the PocketTill catalogue's
/// admin-enhanced versions - see Settings > Product Images and
/// SCHEMA_TRUTH.md's `catalogue_products.is_image_enhanced`.
///
/// Deliberately separate from [SyncService]'s main push/pull cycle (sales,
/// stock, customers) and always run *after* it, fire-and-forget: image
/// syncing is a lower-priority nice-to-have, never something that should
/// slow down or fail alongside the data that actually matters.
class ImageSyncService {
  ImageSyncService({required Isar isar, required ProductRepository productRepository})
    : _isar = isar,
      _productRepository = productRepository;

  final Isar _isar;
  final ProductRepository _productRepository;

  final StreamController<bool> _lowStorageController =
      StreamController<bool>.broadcast();

  /// Emits `true` while device storage is too low to keep downloading
  /// product images (paused, per Settings > Product Images), `false` once a
  /// later sync finds storage healthy again - watched by SalesScreen for a
  /// one-time warning banner that clears itself automatically.
  Stream<bool> get lowStorageWarning => _lowStorageController.stream;

  /// Best-effort - every failure path here (no store, offline, a bad
  /// response) just means "images stay as they were," never a thrown error,
  /// since nothing calls this expecting to await a meaningful result.
  Future<void> syncStoreImages() async {
    try {
      final storeConfig = await _isar.storeConfigs.get(1);
      if (storeConfig == null || !storeConfig.isLoggedIn) return;

      // Checked once per sync cycle, not per product - a single low-storage
      // reading pauses the whole pass rather than letting it burn through
      // whatever little space is left one image at a time.
      if (await ImageCacheService.isStorageLow()) {
        _lowStorageController.add(true);
        return;
      }
      _lowStorageController.add(false);

      final products = await _productRepository.getAll();
      if (products.isEmpty) return;

      // Step 1: pull in any admin-enhanced catalogue image this store
      // doesn't have yet (subject to the toggle) - this can change a
      // product's imageUrl outright. Goes through the normal repository
      // save, same path a manual edit takes, so it correctly enqueues a
      // `product` sync event too (the store's `products.image_url` row
      // should reflect its current displayed photo, not just the local
      // cache) - and, since imageUrl changed, save() itself drops any
      // stale cached file for it. The actual (re)download happens in step
      // 2 below, uniformly for every product that needs it.
      final barcodes = products.map((p) => p.barcode).toSet().toList();
      final enhanced = await SupabaseService.fetchEnhancedCatalogueImages(barcodes);
      for (final product in products) {
        final catalogueUrl = enhanced[product.barcode];
        if (catalogueUrl == null) continue;
        if (product.imageUrl == catalogueUrl) continue; // already current
        if (!_shouldReplace(storeConfig, product)) continue;

        product.imageUrl = catalogueUrl;
        await _productRepository.save(product);
      }

      // Step 2: make sure every product with a photo actually has it
      // cached on-device - not just the ones just touched above. Without
      // this, a product's image only ever got cached the first time its
      // row happened to scroll into view (found 2026-09-08 - the point of
      // a background sync step is exactly to fill this in proactively,
      // not leave it to chance display timing).
      for (final product in products) {
        final url = product.imageUrl;
        if (url == null || url.isEmpty) continue;

        final knownPath = product.cachedImagePath;
        final alreadyCached =
            (knownPath != null && await File(knownPath).exists()) ||
            await ImageCacheService.getCachedFile(product.barcode) != null;
        if (alreadyCached) continue;

        // Storage-low/WiFi-only gating both live inside fetchAndCache - a
        // skip there just means "try again on the next sync," never an
        // error surfaced here.
        final file = await ImageCacheService.fetchAndCache(
          cacheKey: product.barcode,
          remoteUrl: url,
          wifiOnly: storeConfig.imagesWifiOnly,
        );
        if (file == null) continue;
        await _productRepository.updateCachedImagePath(product.uuid, file.path);
      }
    } catch (_) {
      // Background task - never propagate.
    }
  }

  /// Toggle ON means the catalogue's enhanced photo can replace anything,
  /// including a photo the owner uploaded themselves. Toggle OFF only fills
  /// a genuine gap - it never overwrites a photo the owner already has.
  bool _shouldReplace(StoreConfig config, Product product) {
    if (config.useCatalogueImages) return true;
    final hasOwnImage = (product.imageUrl ?? '').isNotEmpty;
    return !hasOwnImage;
  }
}
