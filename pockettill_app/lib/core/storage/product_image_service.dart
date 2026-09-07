import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_service.dart';

/// One image per product, stored in Supabase Storage's `product-images`
/// bucket at `{storeId}/{productUuid}.jpg` (public-read, write-restricted to
/// the owning store - see SCHEMA_TRUTH.md). Always the same key per product,
/// so a re-upload overwrites the previous image in place rather than
/// leaving it orphaned in Storage.
class ProductImageService {
  ProductImageService._();

  static const _bucket = 'product-images';
  static const _maxBytes = 50 * 1024;
  static const _maxDimension = 500;
  static const _minQuality = 20;

  static final ImagePicker _picker = ImagePicker();

  /// Opens the camera or gallery per [source]. Returns null if the user
  /// backed out - never throws for a plain cancellation.
  static Future<File?> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    return picked == null ? null : File(picked.path);
  }

  /// Compresses [source] to a JPEG no larger than roughly [_maxBytes] and no
  /// wider/taller than [_maxDimension]px, then uploads it to this product's
  /// storage path and returns the public URL.
  ///
  /// Compression re-encodes at falling quality until the byte cap is met or
  /// [_minQuality] is reached - a busy/detailed photo may end up slightly
  /// over [_maxBytes] at the quality floor rather than degrade further into
  /// unusable artifacting.
  static Future<String> uploadProductImage({
    required File source,
    required String storeId,
    required String productUuid,
  }) async {
    final compressed = await _compress(source);
    final path = '$storeId/$productUuid.jpg';

    await SupabaseService.supabaseClient.storage
        .from(_bucket)
        .uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    final publicUrl = SupabaseService.supabaseClient.storage
        .from(_bucket)
        .getPublicUrl(path);
    // getPublicUrl returns the same string every time for the same path, but
    // a replace upload changes the bytes at that path in place - without a
    // cache-buster, Flutter's ImageCache (keyed by URL) and any CDN/browser
    // cache in front of Storage keep serving the old image indefinitely,
    // which is exactly the "old photo shows until I force-stop the app" bug
    // this fixes.
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Removes this product's image from Storage outright (the "remove image
  /// entirely" option, as opposed to replacing it - which just re-uploads
  /// to the same path instead).
  static Future<void> deleteProductImage({
    required String storeId,
    required String productUuid,
  }) async {
    final path = '$storeId/$productUuid.jpg';
    try {
      await SupabaseService.supabaseClient.storage.from(_bucket).remove([path]);
    } catch (_) {
      // Already gone, or offline - either way there's nothing left to clean
      // up from the caller's perspective once product.imageUrl is cleared.
    }
  }

  static Future<Uint8List> _compress(File source) async {
    var quality = 85;
    Uint8List? result;

    while (true) {
      result = await FlutterImageCompress.compressWithFile(
        source.absolute.path,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      final doneOnSize = result != null && result.length <= _maxBytes;
      final atQualityFloor = quality <= _minQuality;
      if (doneOnSize || atQualityFloor) break;
      quality -= 15;
    }

    if (result == null) {
      throw StateError('Image compression failed for ${source.path}');
    }
    return result;
  }
}
