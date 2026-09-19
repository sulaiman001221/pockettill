import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:flutter/painting.dart' show FileImage, PaintingBinding;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// On-device cache of product photos, keyed by a stable identifier (a
/// product's uuid). Every product image the app ever displays is downloaded
/// once, compressed to ~50KB, and written to
/// `{appDocDir}/product_images/{cacheKey}.jpg` so it keeps displaying while
/// offline - see Settings > Product Images and SCHEMA_TRUTH.md's
/// `stores.use_catalogue_images`/`images_wifi_only` for the feature this
/// backs.
///
/// Every method here is best-effort and non-throwing by design: a failed
/// download, a skipped WiFi-only download, or low device storage should all
/// just mean "still no cached image" to the caller, never a crash or an
/// error the UI has to handle specially.
class ImageCacheService {
  ImageCacheService._();

  static const _folderName = 'product_images';
  static const _maxBytes = 50 * 1024;
  static const _maxDimension = 500;
  static const _minQuality = 20;

  /// Below this, downloads pause and a one-time warning shows - see
  /// [isStorageLow].
  static const lowStorageThresholdMb = 100;

  static Directory? _cacheDir;

  static Future<Directory> _dir() async {
    final cached = _cacheDir;
    if (cached != null) return cached;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_folderName');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  static Future<File> _fileFor(String cacheKey) async {
    final dir = await _dir();
    return File('${dir.path}/$cacheKey.jpg');
  }

  /// The already-cached file for [cacheKey], or null if nothing's cached (or
  /// the file was removed from disk outside this service, e.g. an OS
  /// storage cleanup).
  static Future<File?> getCachedFile(String cacheKey) async {
    final file = await _fileFor(cacheKey);
    return await file.exists() ? file : null;
  }

  /// True once free device storage drops below [lowStorageThresholdMb].
  /// Best-effort - a platform that can't report free space (or a plugin
  /// failure) is treated as "not low" so it never blocks every download.
  static Future<bool> isStorageLow() async {
    try {
      final freeMb = await DiskSpacePlus().getFreeDiskSpace;
      return freeMb != null && freeMb < lowStorageThresholdMb;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _canDownloadNow({required bool wifiOnly}) async {
    if (!wifiOnly) return true;
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Downloads [remoteUrl], compresses it to ~50KB, and writes it to this
  /// device's cache under [cacheKey], returning the resulting [File].
  ///
  /// Returns null - without throwing - whenever the download doesn't
  /// happen: offline or the request fails, [wifiOnly] is set and there's no
  /// WiFi connection right now, or [isStorageLow]. Every one of those is
  /// meant to leave the caller exactly where it started (still showing the
  /// old cached file or a placeholder), not surface as an error.
  static Future<File?> fetchAndCache({
    required String cacheKey,
    required String remoteUrl,
    required bool wifiOnly,
  }) async {
    if (!await _canDownloadNow(wifiOnly: wifiOnly)) return null;
    if (await isStorageLow()) return null;

    try {
      final response = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final compressed = await _compress(response.bodyBytes);
      final file = await _fileFor(cacheKey);
      await file.writeAsBytes(compressed, flush: true);
      // Image.file/FileImage cache decoded bytes keyed by this file's path,
      // not its content - overwriting the same path with a replacement
      // photo leaves Flutter's global ImageCache still holding the old
      // decoded image until this is evicted, which is why a re-uploaded
      // photo kept showing the pre-edit picture on Stock despite the disk
      // file and Product.imageUrl both already being correct. Found
      // 2026-09-19.
      PaintingBinding.instance.imageCache.evict(FileImage(file));
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Removes [cacheKey]'s cached file, if any - e.g. when its product is
  /// deleted, or right before [fetchAndCache] writes a newer replacement
  /// under the same key (a plain overwrite already replaces the bytes in
  /// place, so this is mainly for deletion).
  static Future<void> deleteCachedFile(String cacheKey) async {
    final file = await _fileFor(cacheKey);
    PaintingBinding.instance.imageCache.evict(FileImage(file));
    if (await file.exists()) await file.delete();
  }

  /// Total bytes currently held in the cache folder - Settings' "Images
  /// cached: X MB" row.
  static Future<int> totalCacheBytes() async {
    final dir = await _dir();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Deletes every cached image outright - Settings' "Clear image cache"
  /// action. Nothing re-downloads until each product's image is next
  /// displayed or the next background image sync runs, same as after a
  /// fresh install.
  static Future<void> clearCache() async {
    final dir = await _dir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is File) await entity.delete();
    }
    PaintingBinding.instance.imageCache.clear();
  }

  /// Re-encodes at falling quality until [_maxBytes] is met or [_minQuality]
  /// is reached - mirrors ProductImageService._compress, just working from
  /// already-downloaded bytes instead of a local [File] picked from the
  /// gallery/camera.
  static Future<Uint8List> _compress(Uint8List bytes) async {
    var quality = 85;
    Uint8List result;

    while (true) {
      result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      final doneOnSize = result.length <= _maxBytes;
      final atQualityFloor = quality <= _minQuality;
      if (doneOnSize || atQualityFloor) break;
      quality -= 15;
    }

    return result;
  }
}
