import 'package:flutter/material.dart';

import '../../shared/models/product.dart';
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

/// Display label for a [ProductStockStatus].
String stockStatusLabel(ProductStockStatus status) {
  switch (status) {
    case ProductStockStatus.normal:
      return 'Normal';
    case ProductStockStatus.lowStock:
      return 'Low Stock';
    case ProductStockStatus.outOfStock:
      return 'Out of Stock';
  }
}

/// Brand colour for a [ProductStockStatus] (green/amber/red).
Color stockStatusColor(ProductStockStatus status) {
  switch (status) {
    case ProductStockStatus.normal:
      return AppTheme.syncGreen;
    case ProductStockStatus.lowStock:
      return AppTheme.syncAmber;
    case ProductStockStatus.outOfStock:
      return AppTheme.logoutRed;
  }
}

/// A small palette to derive a consistent avatar colour per product name.
const List<Color> _avatarPalette = [
  Color(0xFF5170FF),
  Color(0xFF38A169),
  Color(0xFFD69E2E),
  Color(0xFFE53E3E),
  Color(0xFF8B5CF6),
  Color(0xFF0891B2),
  Color(0xFFDB2777),
  Color(0xFFEA580C),
];

/// Deterministically picks an avatar colour from [name] - the same name
/// always produces the same colour.
Color avatarColorForName(String name) {
  if (name.isEmpty) return _avatarPalette.first;
  return _avatarPalette[name.toLowerCase().hashCode.abs() % _avatarPalette.length];
}

/// Round coloured-letter avatar used for a product's first initial.
class ProductAvatar extends StatelessWidget {
  const ProductAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: avatarColorForName(name),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Small pill badge showing a product's stock status.
class StockStatusBadge extends StatelessWidget {
  const StockStatusBadge({super.key, required this.status});

  final ProductStockStatus status;

  @override
  Widget build(BuildContext context) {
    final color = stockStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            stockStatusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
