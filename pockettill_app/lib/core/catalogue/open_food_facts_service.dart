import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fields pulled from an Open Food Facts product lookup. [brands] and
/// [imageUrl] are captured but not shown anywhere yet - reserved for a
/// post-beta feature.
class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({
    this.name,
    this.mass,
    this.category,
    this.brands,
    this.imageUrl,
  });

  final String? name;
  final String? mass;
  final String? category;
  final String? brands;
  final String? imageUrl;

  factory OpenFoodFactsProduct.fromJson(Map<String, dynamic> json) {
    final name = json['product_name'] as String?;
    final quantity = json['quantity'] as String?;

    String? category;
    final tags = json['categories_tags'];
    if (tags is List && tags.isNotEmpty && tags.first is String) {
      final tag = tags.first as String;
      final stripped = tag.startsWith('en:') ? tag.substring(3) : tag;
      if (stripped.isNotEmpty) {
        category = _toPocketTillCase(stripped);
      }
    }

    return OpenFoodFactsProduct(
      name: (name != null && name.isNotEmpty)
          ? _toPocketTillCase(_stripMassFromName(name))
          : null,
      mass: (quantity != null && quantity.isNotEmpty)
          ? _normalizeMass(quantity)
          : null,
      category: category,
      brands: json['brands'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }
}

/// Strips an embedded mass/size token (e.g. "2L", "500ml", "1.5 L") from a
/// raw Open Food Facts product name before it's title-cased - Open Food
/// Facts often folds the pack size directly into the name (e.g.
/// "Coca-Cola 2L"), which would otherwise show up twice: once in the name,
/// once in [OpenFoodFactsProduct.mass]. The digit group's decimal point (as
/// in "1.5L") is matched as part of the same token so it's removed whole,
/// rather than left behind as a stray trailing ".". Falls back to the
/// original (trimmed) name if stripping would empty it out entirely.
String _stripMassFromName(String input) {
  final stripped = input
      .replaceAll(
        RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:ml|cl|dl|l|kg|g)\b', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'[-,]\s*$'), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  return stripped.isEmpty ? input.trim() : stripped;
}

/// Normalizes a raw Open Food Facts quantity string (e.g. "2 l", "300ML") to
/// PocketTill's convention: the numeric part untouched (so a decimal like
/// "1.5" never gets mangled), no space before the unit, and the unit
/// lowercase - except a bare "l" (litres), which stays uppercase ("L") to
/// match standard packaging convention and avoid reading as the digit 1.
/// Leaves the string as-is if it doesn't match the simple
/// number-then-letters shape (e.g. a multipack like "6 x 330ml").
String _normalizeMass(String input) {
  final trimmed = input.trim();
  final match = RegExp(r'^([\d.,]+)\s*([A-Za-z]+)$').firstMatch(trimmed);
  if (match == null) return trimmed;
  final number = match.group(1)!;
  final unit = match.group(2)!;
  final normalizedUnit = unit.toLowerCase() == 'l' ? 'L' : unit.toLowerCase();
  return '$number$normalizedUnit';
}

/// Normalizes a raw Open Food Facts word-based field (name, category) to
/// PocketTill's naming convention: each word capitalized, the rest
/// lowercase, with any run of whitespace or punctuation between words
/// collapsed to a single space - Open Food Facts data is inconsistent about
/// this (double spaces, hyphens/underscores standing in for spaces in
/// category tags). Deliberately not used for [OpenFoodFactsProduct.mass]:
/// splitting on non-alphanumeric characters would break up a decimal
/// quantity like "1.5 L".
String _toPocketTillCase(String input) {
  final words = input
      .trim()
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty);
  if (words.isEmpty) return input.trim();
  return words
      .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');
}

/// Fallback barcode lookup against Open Food Facts (world.openfoodfacts.org)
/// for a barcode that isn't in PocketTill's own verified catalogue.
///
/// A free, keyless public API, but it asks integrators to self-throttle
/// (15 requests/minute/IP) and identify their app via User-Agent - both
/// enforced here rather than trusted to the caller: [lookup] calls chain
/// onto a single queue so concurrent scans are serialized, each waiting out
/// [_minInterval] since the previous *call* (not previous success), and
/// every request carries the required header.
///
/// Every failure mode (offline, timeout, non-200, `status != 1`, malformed
/// JSON) resolves to `null` rather than throwing - this is a silent
/// fallback layer, never something the cashier should see an error for.
class OpenFoodFactsService {
  OpenFoodFactsService._();

  static final OpenFoodFactsService instance = OpenFoodFactsService._();

  static const _minInterval = Duration(seconds: 4);
  static const _timeout = Duration(seconds: 8);
  static const _userAgent =
      'PocketTill/1.0.0 (co.pockettill.app; contact: hello@pockettill.co.za)';

  DateTime? _lastCallAt;
  Future<void> _queue = Future.value();

  /// Looks up [barcode]. Queues behind any lookup already in flight so
  /// rapid successive scans are processed one at a time rather than firing
  /// concurrent requests.
  Future<OpenFoodFactsProduct?> lookup(String barcode) {
    final result = _queue.then((_) => _throttledFetch(barcode));
    // Keep the queue alive regardless of this lookup's outcome, so one
    // failed/timed-out call doesn't break the chain for the next one.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<OpenFoodFactsProduct?> _throttledFetch(String barcode) async {
    final lastCall = _lastCallAt;
    if (lastCall != null) {
      final elapsed = DateTime.now().difference(lastCall);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }
    _lastCallAt = DateTime.now();
    return _fetch(barcode);
  }

  Future<OpenFoodFactsProduct?> _fetch(String barcode) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
      '?fields=product_name,quantity,categories_tags,brands,image_url',
    );

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] != 1) return null;

      final product = json['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      return OpenFoodFactsProduct.fromJson(product);
    } catch (_) {
      return null;
    }
  }
}
