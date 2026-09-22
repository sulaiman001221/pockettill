import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/image_cache_service.dart';
import '../../shared/models/product.dart';
import '../../shared/repositories/store_config_provider.dart';
import '../../shared/theme/app_theme.dart';

/// Combines [Product.name] and [Product.mass] into one display string so
/// naming reads consistently everywhere, e.g. "Coca Cola" + "2L" becomes
/// "Coca Cola 2L".
String productDisplayName(Product product) {
  final mass = product.mass?.trim();
  if (mass == null || mass.isEmpty) return product.name;
  return '${product.name} $mass';
}

/// A product's stock status, derived from [Product.stock] against
/// [Product.lowStockThreshold].
enum ProductStockStatus { normal, lowStock, outOfStock }

/// Classifies [product] into a [ProductStockStatus].
ProductStockStatus stockStatusOf(Product product) {
  if (product.stock <= 0) return ProductStockStatus.outOfStock;
  if (product.stock <= product.lowStockThreshold) {
    return ProductStockStatus.lowStock;
  }
  return ProductStockStatus.normal;
}

/// Colour for a [ProductStockStatus]'s "X in stock" text - plain secondary
/// grey normally, amber once low, red at zero. There's no badge/pill
/// anymore (per Figma spec, 2026-09-05) - the stock-count text itself is
/// the only signal.
Color stockStatusColor(ProductStockStatus status) {
  switch (status) {
    case ProductStockStatus.normal:
      return AppTheme.textSecondary;
    case ProductStockStatus.lowStock:
      return AppTheme.syncAmber;
    case ProductStockStatus.outOfStock:
      return AppTheme.logoutRed;
  }
}

/// Shows a product's photo cache-first, per Settings > Product Images: a
/// product's photo is keyed by [cacheKey] (its barcode - shared between a
/// store's own [Product] and the same item browsed in Catalogue Browse, so
/// an image cached from one view is already there for the other) rather
/// than served straight off the network at display time.
///
/// Resolution order: [cachedImagePath] if it still exists on disk; else
/// whatever's already cached under [cacheKey] (covers a caller that doesn't
/// know the path yet); else, if online and [imageUrl] is set, download +
/// compress + cache it via [ImageCacheService] and display *that* file once
/// ready - the bytes are never handed to Image.network directly, even the
/// first time an image is shown. A [wifiOnly] connection with no WiFi, or
/// low device storage, both just mean this stays on the placeholder until
/// the next successful sync/display attempt.
class CachedProductImage extends ConsumerStatefulWidget {
  const CachedProductImage({
    super.key,
    required this.cacheKey,
    required this.imageUrl,
    required this.cachedImagePath,
    required this.fit,
    required this.placeholder,
    required this.loadingPlaceholder,
  });

  final String cacheKey;
  final String? imageUrl;
  final String? cachedImagePath;
  final BoxFit fit;
  final Widget placeholder;
  final Widget loadingPlaceholder;

  @override
  ConsumerState<CachedProductImage> createState() => _CachedProductImageState();
}

class _CachedProductImageState extends ConsumerState<CachedProductImage> {
  File? _file;
  bool _loading = false;

  // Bumped on every _resolve() call and captured locally by each one - lets
  // a call whose result comes back after a *newer* call has already started
  // recognize it's stale and drop its result instead of setState-ing over
  // it. Needed because Flutter reuses this State positionally in a list
  // with no per-item key (Stock, Catalogue Browse): switching Catalogue
  // Browse categories swaps in a whole new set of items at the same list
  // positions, which calls didUpdateWidget (not initState) on the existing
  // State objects and starts a fresh _resolve() while a slower one from the
  // *previous* category's item at that position can still be in flight -
  // without this guard, whichever call happened to finish last would win,
  // regardless of which item is actually showing by then, which is exactly
  // how a switched-away-from category's photo ended up "stuck" on a
  // different product. Found 2026-09-23 on Catalogue Browse.
  int _resolveId = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant CachedProductImage old) {
    super.didUpdateWidget(old);
    if (old.cacheKey != widget.cacheKey ||
        old.imageUrl != widget.imageUrl ||
        old.cachedImagePath != widget.cachedImagePath) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final id = ++_resolveId;
    bool stillCurrent() => mounted && id == _resolveId;

    final knownPath = widget.cachedImagePath;
    if (knownPath != null && knownPath.isNotEmpty) {
      final file = File(knownPath);
      if (await file.exists()) {
        if (stillCurrent()) setState(() => _file = file);
        return;
      }
    }

    final cached = await ImageCacheService.getCachedFile(widget.cacheKey);
    if (cached != null) {
      if (stillCurrent()) setState(() => _file = cached);
      return;
    }

    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      if (stillCurrent()) setState(() => _file = null);
      return;
    }

    if (stillCurrent()) setState(() => _loading = true);
    final wifiOnly = ref.read(storeConfigProvider)?.imagesWifiOnly ?? false;
    final downloaded = await ImageCacheService.fetchAndCache(
      cacheKey: widget.cacheKey,
      remoteUrl: url,
      wifiOnly: wifiOnly,
    );
    if (!stillCurrent()) return;
    setState(() {
      _file = downloaded;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) {
      return Image.file(
        file,
        fit: widget.fit,
        errorBuilder: (_, _, _) => widget.placeholder,
      );
    }
    if (_loading) return widget.loadingPlaceholder;
    return widget.placeholder;
  }
}

/// A product's photo, or a plain grey placeholder with a generic
/// shopping-bag glyph when there isn't one - same placeholder style used
/// everywhere a product appears without a photo (Stock, Catalogue Browse,
/// Till), rather than a per-product colour/letter. Matches how Shopify
/// POS/Square/Loyverse all handle a missing product photo: a photo grid
/// full of random-colored letter avatars reads as noise, a single neutral
/// placeholder doesn't.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.borderRadius,
    this.cacheKey,
    this.cachedImagePath,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// Defaults to a corner radius proportional to [size], matching the
  /// 12px-at-44px ratio used elsewhere for this shape.
  final double? borderRadius;

  /// This product's barcode, for the on-device image cache. Null skips
  /// caching entirely and falls back to a plain `Image.network` - used only
  /// by add_product_screen.dart's live preview card, where there's no
  /// durable product yet to key a cache entry off.
  final String? cacheKey;

  /// This product's already-known local cache path, if any (Product.
  /// cachedImagePath) - passing it avoids an extra disk check when it's
  /// already on hand.
  final String? cachedImagePath;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * (12 / 44);
    final url = imageUrl;
    final key = cacheKey;

    if (key != null && key.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: CachedProductImage(
            cacheKey: key,
            imageUrl: url,
            cachedImagePath: cachedImagePath,
            fit: BoxFit.cover,
            placeholder: _placeholder(radius),
            loadingPlaceholder: _loadingPlaceholder(radius),
          ),
        ),
      );
    }

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(radius),
        ),
      );
    }
    return _placeholder(radius);
  }

  Widget _placeholder(double radius) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.divider,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.image,
        color: AppTheme.iconBorder,
        size: size * 0.5,
      ),
    );
  }

  Widget _loadingPlaceholder(double radius) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppTheme.divider,
      child: SizedBox(
        width: size * 0.35,
        height: size * 0.35,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// Shared "big image" list row/card for Stock and Catalogue Browse -
/// reverted 2026-09-06 back to a white card (per the user's original
/// reference design) after the divider-only, no-card Figma spec (2026-09-05)
/// turned out to read poorly: the #F0F0F0 divider was barely visible
/// against the page background, and product photos with their own white
/// background had nothing to visually separate one row from the next.
///
/// The image shrank from the Figma spec's 115x121 to make room for real
/// card padding around it (previously that "padding" was just centering
/// math with no visible card boundary, so the image could be as large as
/// the spec's target row height allowed).
///
/// Content still splits top/bottom against the image's own height rather
/// than sitting as one vertically-centered block: [name] (plus optional
/// [subtitle] right under it) pins to the image's top edge, while
/// [bottomLeft] and [trailing] share a row pinned to the image's bottom
/// edge - freeing the name to use the full row width instead of competing
/// with the trailing buttons for space.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.bottomLeft,
    required this.trailing,
    this.subtitle,
    this.onTap,
    this.cacheKey,
    this.cachedImagePath,
  });

  static const double imageWidth = 98;
  static const double imageHeight = 102;

  static const double _cardPadding = 10;
  static const double _horizontalMargin = 20; // matches every other page's own edge padding

  final String name;
  final String? imageUrl;
  final Widget? subtitle;
  final Widget bottomLeft;
  final Widget trailing;
  final VoidCallback? onTap;

  /// This row's barcode, for the on-device image cache - see
  /// [ProductAvatar.cacheKey]. Null falls back to a plain `Image.network`.
  final String? cacheKey;

  /// This row's already-known local cache path, if any.
  final String? cachedImagePath;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            _horizontalMargin,
            0,
            _horizontalMargin,
            12,
          ),
          padding: const EdgeInsets.all(_cardPadding),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: imageWidth,
                height: imageHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  // White, not the page's grey background - most product
                  // photos are shot on a white background themselves, so
                  // this makes them blend in rather than sitting on a
                  // visibly different grey square.
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: cacheKey != null && cacheKey!.isNotEmpty
                    ? CachedProductImage(
                        cacheKey: cacheKey!,
                        imageUrl: imageUrl,
                        cachedImagePath: cachedImagePath,
                        // contain, not cover - a white-background product
                        // photo should never be cropped just to fill the
                        // box, since the whole point is letting its own
                        // white background merge with the card's.
                        fit: BoxFit.contain,
                        placeholder: const _RowImagePlaceholder(),
                        loadingPlaceholder: const _RowImagePlaceholder(loading: true),
                      )
                    : (imageUrl != null && imageUrl!.isNotEmpty)
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const _RowImagePlaceholder(),
                      )
                    : const _RowImagePlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ConstrainedBox(
                  // A minimum, not a fixed height - a hard SizedBox here
                  // clipped/overflowed by design whenever the name wrapped
                  // to 2 lines plus a full-size trailing control (e.g.
                  // Catalogue's Checkbox, ~48px tall) needed more room than
                  // the image's own height. Letting the card grow slightly
                  // taller in that case is a much better failure mode than
                  // a 1px RenderFlex overflow (found 2026-09-06).
                  constraints: const BoxConstraints(minHeight: imageHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // Centered as one block, not spaceBetween pinning name
                    // to the image's top edge and price to its bottom edge -
                    // reads more consistent against the image, which is
                    // itself vertically centered in the row (2026-09-07).
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            subtitle!,
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: bottomLeft),
                          const SizedBox(width: 8),
                          trailing,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _RowImagePlaceholder extends StatelessWidget {
  const _RowImagePlaceholder({this.loading = false});

  /// Shows a small spinner instead of the image glyph while a
  /// [CachedProductImage] is still downloading/caching - only ever true for
  /// the split-second before a network image lands in the local cache.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // Light grey, not white (2026-09-06) - white was indistinguishable from
    // the white card now surrounding it, so a "no photo yet" product looked
    // like it had a blank white gap instead of an obvious placeholder. Fills
    // the same full image slot as a real photo would, so it still aligns
    // top-with-name/bottom-with-price the same way.
    return Container(
      color: AppTheme.divider,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(
              Icons.image,
              color: AppTheme.actionDark,
              size: 46,
            ),
    );
  }
}

/// The small square icon buttons on the right of a Stock [ProductRow] (edit
/// pencil, quick-add plus) - same rounded-square shape, sized/coloured per
/// caller.
class RowSquareButton extends StatelessWidget {
  const RowSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.iconColor,
    this.border,
    this.size = 36,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;
  final Color? border;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}

/// Computes ((selling - cost) / selling) * 100, or null if either price is
/// missing/invalid.
double? profitMarginPercent({required double? sellingPrice, required double? costPrice}) {
  if (sellingPrice == null || costPrice == null || sellingPrice <= 0) {
    return null;
  }
  return ((sellingPrice - costPrice) / sellingPrice) * 100;
}

/// Colour for a margin percentage: green above 20%, amber 10-20%, red below.
Color marginColor(double marginPercent) {
  if (marginPercent > 20) return AppTheme.syncGreen;
  if (marginPercent >= 10) return AppTheme.syncAmber;
  return AppTheme.logoutRed;
}
