import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fields pulled from an Open Food Facts product lookup. No category - Open
/// Food Facts' category taxonomy doesn't map cleanly onto PocketTill's own
/// categories, so it's deliberately never auto-filled from here (Layer 1,
/// PocketTill's own verified catalogue, still supplies one - this only
/// affects the Layer 2 OFF fallback).
class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({this.name, this.mass, this.imageUrl});

  final String? name;
  final String? mass;
  final String? imageUrl;

  factory OpenFoodFactsProduct.fromJson(Map<String, dynamic> json) {
    final rawName = json['product_name'] as String?;
    final quantity = json['quantity'] as String?;
    final brand = (json['brands'] as String?)?.split(',').first.trim();

    String? name;
    if (rawName != null && rawName.isNotEmpty) {
      final stripped = _stripMassFromName(rawName);
      // Brand-first matches PocketTill's own naming convention (e.g. "Jungle
      // Banana Flavoured Porridge") - skip prepending it if OFF's own name
      // already leads with it, so it doesn't end up doubled.
      final hasBrand = brand != null && brand.isNotEmpty;
      final alreadyLeadsWithBrand =
          hasBrand && stripped.toLowerCase().startsWith(brand.toLowerCase());
      final combined = (hasBrand && !alreadyLeadsWithBrand)
          ? '$brand $stripped'
          : stripped;
      name = _toPocketTillCase(combined);
    }

    return OpenFoodFactsProduct(
      name: name,
      mass: (quantity != null && quantity.isNotEmpty)
          ? _normalizeMass(quantity)
          : null,
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

/// Words that stay lowercase unless they open the name - standard title-case
/// convention ("Sauce of the Day", not "Sauce Of The Day"). Mirrors
/// pockettill_datamaster/src/lib/catalogue-format.ts's MINOR_WORDS - keep
/// both in sync.
const _minorWords = {
  'a', 'an', 'and', 'are', 'as', 'at', 'but', 'by', 'for', 'in', 'is',
  'nor', 'of', 'on', 'or', 'the', 'to', 'with',
};

/// Uppercases the first letter found in [word] and lowercases every other
/// letter, leaving every non-letter character (digits, %, &, ...) exactly
/// where it was.
String _capitalizeLetters(String word) {
  var seenFirstLetter = false;
  return word.replaceAllMapped(RegExp(r'[A-Za-z]'), (match) {
    final letter = match[0]!;
    if (seenFirstLetter) return letter.toLowerCase();
    seenFirstLetter = true;
    return letter.toUpperCase();
  });
}

/// Normalizes a raw Open Food Facts product name to PocketTill's naming
/// convention: title-cased, split on whitespace only, so punctuation *within*
/// a word (%, /, &, a hyphen) - meaningful on a product label - is preserved
/// exactly instead of being treated as a word boundary to throw away.
/// Splitting on every non-alphanumeric run used to silently delete it: "100%
/// Pulp" became "100 Pulp", "Rice/Pasta" became "Rice Pasta". A hyphen or
/// slash still starts a fresh capital on each side ("stir-fry" ->
/// "Stir-Fry"), just without discarding the character itself; a word in
/// [_minorWords] stays lowercase unless it opens the name. Same fix as
/// pockettill_datamaster's catalogue-format.ts (found and fixed there
/// 2026-09-23, ported here 2026-09-24). Deliberately not used for
/// [OpenFoodFactsProduct.mass], which has its own [_normalizeMass].
String _toPocketTillCase(String input) {
  final words = input
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return input.trim();

  final cased = <String>[];
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (i > 0 && _minorWords.contains(word.toLowerCase())) {
      cased.add(word.toLowerCase());
      continue;
    }
    cased.add(
      word.splitMapJoin(
        RegExp(r'[-/]'),
        onMatch: (match) => match[0]!,
        onNonMatch: _capitalizeLetters,
      ),
    );
  }
  return cased.join(' ');
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
      '?fields=product_name,quantity,brands,image_url',
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
