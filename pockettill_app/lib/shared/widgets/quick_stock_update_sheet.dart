import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Bottom sheet asking "how many units do you have?" for a product that's
/// out of stock (or about to go negative at checkout). Pops with the entered
/// quantity, or null if cancelled - the caller decides what to do with it
/// (call [ProductRepository.adjustStock], add to cart, show a snackbar,
/// etc.), since that differs between where this sheet is shown from.
class QuickStockUpdateSheet extends StatefulWidget {
  const QuickStockUpdateSheet({
    super.key,
    required this.productName,
    this.confirmLabel = 'Update Stock & Add to Cart',
  });

  final String productName;
  final String confirmLabel;

  @override
  State<QuickStockUpdateSheet> createState() => _QuickStockUpdateSheetState();
}

class _QuickStockUpdateSheetState extends State<QuickStockUpdateSheet> {
  final _controller = TextEditingController();

  int? get _quantity => int.tryParse(_controller.text.trim());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: AppTheme.syncAmber,
            ),
            const SizedBox(height: 12),
            const Text(
              'Out of Stock',
              textAlign: TextAlign.center,
              style: AppTheme.mainTitle,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.productName} is currently out of stock.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySubtitle,
            ),
            const SizedBox(height: 20),
            const Text(
              'Quick Stock Update',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'How many units do you have?',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_quantity ?? 0) > 0
                    ? () => Navigator.of(context).pop(_quantity)
                    : null,
                child: Text(widget.confirmLabel),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
