import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../shared/models/product.dart';
import '../../shared/theme/app_theme.dart';
import 'add_product_screen.dart';
import 'stock_ui.dart';

/// Shown after successfully adding a new product (never after an edit -
/// edits use a snackbar back on the Stock screen instead).
class ProductSuccessScreen extends StatefulWidget {
  const ProductSuccessScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductSuccessScreen> createState() => _ProductSuccessScreenState();
}

class _ProductSuccessScreenState extends State<ProductSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addAnother() {
    // pushReplacement only swaps out this Success screen - the AddProduct
    // screen that led here would still sit underneath, stale form data and
    // all. Pop both, then push a genuinely fresh form.
    Navigator.of(context)
      ..pop()
      ..pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddProductScreen()));
  }

  void _goToStock() {
    // Stack is Shell -> Stock -> AddProduct -> Success; pop the last two.
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  void _goToSales() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final margin = profitMarginPercent(
      sellingPrice: product.price,
      costPrice: product.costPrice,
    );
    final time = DateFormat('h:mm a').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.syncGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.syncGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Product Added!', style: AppTheme.mainTitle),
              const SizedBox(height: 8),
              Text(
                '${productDisplayName(product)} has been added to your stock.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySubtitle,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Just now · $time',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _ProductSummaryCard(product: product, margin: margin),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _addAnother,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Product'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _goToStock,
                  child: const Text('Go to Stock'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _goToSales,
                child: const Text('Go to Sales'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSummaryCard extends StatelessWidget {
  const _ProductSummaryCard({required this.product, required this.margin});

  final Product product;
  final double? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProductAvatar(name: product.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productDisplayName(product),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${product.category ?? 'Uncategorised'} · ${product.stock} units',
                      style: AppTheme.bodySubtitle,
                    ),
                  ],
                ),
              ),
              Text(
                'R${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'In Stock', value: '${product.stock}'),
              _Stat(
                label: 'Sell Price',
                value: 'R${product.price.toStringAsFixed(2)}',
              ),
              _Stat(
                label: 'Margin',
                value: margin != null ? '${margin!.toStringAsFixed(0)}%' : '—',
                valueColor: margin != null ? marginColor(margin!) : null,
              ),
              _Stat(
                label: 'Alert At',
                value: '${product.lowStockThreshold}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
