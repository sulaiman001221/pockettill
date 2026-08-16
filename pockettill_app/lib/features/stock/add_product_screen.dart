import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogue/open_food_facts_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/sync/reachability_service.dart';
import '../../shared/models/product.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import 'barcode_scanner_screen.dart';
import 'product_success_screen.dart';
import 'stock_ui.dart';

const List<String> _categoryOptions = ['Drinks', 'Snacks', 'Groceries', 'Other'];

/// Add/edit product form. Create mode when [existingProduct] is null, edit
/// mode otherwise. All writes go through [productRepositoryProvider].
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key, this.existingProduct, this.initialBarcode});

  final Product? existingProduct;

  /// Pre-fills the barcode field in create mode - e.g. when arriving here
  /// from a sale-screen scan that didn't match any existing product.
  final String? initialBarcode;

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _massController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController(text: '5');

  String? _selectedCategoryChip;
  bool _catalogueAutoFilled = false;
  bool _offAutoFilled = false;
  // Captured from Open Food Facts but not shown anywhere yet - reserved for
  // a post-beta feature (see OpenFoodFactsProduct).
  // ignore: unused_field
  String? _offBrands;
  // ignore: unused_field
  String? _offImageUrl;
  bool _saving = false;

  bool get _isEditMode => widget.existingProduct != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProduct;
    if (existing != null) {
      _barcodeController.text = existing.barcode;
      _nameController.text = existing.name;
      _massController.text = existing.mass ?? '';
      _priceController.text = existing.price.toStringAsFixed(2);
      _costController.text = existing.costPrice?.toStringAsFixed(2) ?? '';
      _stockController.text = '${existing.stock}';
      _lowStockController.text = '${existing.lowStockThreshold}';
      if (existing.category != null) {
        _applyCategory(existing.category!);
      }
    } else if (widget.initialBarcode != null &&
        widget.initialBarcode!.isNotEmpty) {
      _barcodeController.text = widget.initialBarcode!;
    }

    for (final controller in [
      _barcodeController,
      _nameController,
      _massController,
      _priceController,
      _costController,
      _stockController,
      _customCategoryController,
    ]) {
      controller.addListener(_onFormChanged);
    }

    if (existing == null &&
        widget.initialBarcode != null &&
        widget.initialBarcode!.isNotEmpty) {
      _lookupCatalogue(widget.initialBarcode!);
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _massController.dispose();
    _customCategoryController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  void _applyCategory(String category) {
    if (_categoryOptions.contains(category)) {
      _selectedCategoryChip = category;
      _customCategoryController.clear();
    } else {
      _selectedCategoryChip = 'Other';
      _customCategoryController.text = category;
    }
  }

  String? _resolvedCategory() {
    if (_selectedCategoryChip == null) return null;
    if (_selectedCategoryChip == 'Other') {
      final custom = _customCategoryController.text.trim();
      return custom.isEmpty ? null : custom;
    }
    return _selectedCategoryChip;
  }

  double? get _sellingPriceValue => double.tryParse(_priceController.text.trim());
  double? get _costPriceValue {
    final text = _costController.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  bool get _canSave =>
      _nameController.text.trim().length >= 2 &&
      (_sellingPriceValue ?? 0) > 0;

  /// Layer 1 (PocketTill's own verified catalogue) first; if that finds
  /// nothing, falls through to Layer 2 (Open Food Facts). Layer 3 is just
  /// the form sitting there for manual entry - no code path needed for it.
  Future<void> _lookupCatalogue(String barcode) async {
    if (barcode.isEmpty) return;

    final foundInOwnCatalogue = await _lookupOwnCatalogue(barcode);
    if (foundInOwnCatalogue || !mounted) return;

    await _lookupOpenFoodFacts(barcode);
  }

  /// Layer 1 - do not change (per spec, this lookup already exists as-is).
  /// Returns whether a match was found and applied.
  Future<bool> _lookupOwnCatalogue(String barcode) async {
    try {
      // Supabase: shared catalogue - verified only (filtered inside
      // fetchCatalogueProduct itself).
      final results = await SupabaseService.fetchCatalogueProduct(
        barcode,
      ).timeout(const Duration(seconds: 4));
      if (!mounted || results.isEmpty) return false;
      final row = results.first;
      setState(() {
        // A catalogue match always overwrites name/mass/category, even if
        // the cashier already typed something in - the whole point of
        // scanning is to trust the shared catalogue's data over a manual
        // guess made before the lookup came back.
        final name = row['name'] as String?;
        if (name != null && name.isNotEmpty) {
          _nameController.text = name;
        }
        final mass = row['mass'] as String?;
        if (mass != null && mass.isNotEmpty) {
          _massController.text = mass;
        }
        final category = row['category'] as String?;
        if (category != null && category.isNotEmpty) {
          _applyCategory(category);
        }
        _catalogueAutoFilled = true;
        _offAutoFilled = false;
      });
      return true;
    } catch (_) {
      // Offline, or the lookup failed - barcode entry still works without
      // catalogue auto-fill.
      return false;
    }
  }

  /// Layer 2 - only reached when Layer 1 found nothing. Silent on every
  /// failure mode (offline, timeout, not-found, malformed response): the
  /// cashier just sees the form stay empty for manual entry, never an
  /// error. Never marks the product verified - Open Food Facts data is a
  /// starting point the admin still reviews in DataMaster like any other
  /// unverified submission.
  Future<void> _lookupOpenFoodFacts(String barcode) async {
    if (!ref.read(reachabilityServiceProvider).currentlyReachable) return;

    final product = await OpenFoodFactsService.instance.lookup(barcode);
    if (!mounted || product == null) return;

    setState(() {
      if (product.name != null) _nameController.text = product.name!;
      if (product.mass != null) _massController.text = product.mass!;
      if (product.category != null) _applyCategory(product.category!);
      _offBrands = product.brands;
      _offImageUrl = product.imageUrl;
      _offAutoFilled = true;
      _catalogueAutoFilled = false;
    });
  }

  Future<void> _rescan() async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode != null && barcode.isNotEmpty && mounted) {
      setState(() => _barcodeController.text = barcode);
      await _lookupCatalogue(barcode);
    }
  }

  /// Checks the barcode (if any) and the name+mass combination against every
  /// other product, excluding the one being edited. Returns a user-facing
  /// error message if a duplicate is found, or null if it's safe to save.
  Future<String?> _findDuplicateError() async {
    final repo = ref.read(productRepositoryProvider);
    final currentUuid = widget.existingProduct?.uuid;
    final barcode = _barcodeController.text.trim();

    if (barcode.isNotEmpty) {
      // Local: store's own products - no verification filter. A store can
      // always find its own products regardless of catalogue verification
      // status.
      final existingByBarcode = await repo.getByBarcode(barcode);
      if (existingByBarcode != null && existingByBarcode.uuid != currentUuid) {
        return 'This barcode is already used by another product';
      }
    }

    final normalizedName = _nameController.text.trim().toLowerCase();
    final normalizedMass = _massController.text.trim().toLowerCase();
    final allProducts = await repo.getAll();
    final hasDuplicate = allProducts.any((p) {
      if (p.uuid == currentUuid) return false;
      final sameName = p.name.trim().toLowerCase() == normalizedName;
      final sameMass = (p.mass ?? '').trim().toLowerCase() == normalizedMass;
      return sameName && sameMass;
    });
    if (hasDuplicate) return 'Product already exists';

    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final duplicateError = await _findDuplicateError();
    if (duplicateError != null) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(duplicateError),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
      return;
    }

    final product = widget.existingProduct ?? (Product()..uuid = '');
    final mass = _massController.text.trim();
    product
      ..barcode = _barcodeController.text.trim()
      ..name = _nameController.text.trim()
      ..mass = mass.isEmpty ? null : mass
      ..category = _resolvedCategory()
      ..price = _sellingPriceValue!
      ..costPrice = _costPriceValue
      ..stock = int.parse(_stockController.text.trim())
      ..lowStockThreshold =
          int.tryParse(_lowStockController.text.trim()) ?? 5;

    await ref.read(productRepositoryProvider).save(product);

    if (!mounted) return;
    setState(() => _saving = false);

    // Pushing a new route doesn't reliably dismiss the keyboard on its own -
    // without this, a still-focused field's keyboard stays open over
    // ProductSuccessScreen, shrinking its viewport enough to overflow.
    FocusScope.of(context).unfocus();

    if (_isEditMode) {
      Navigator.of(context).pop('updated');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductSuccessScreen(product: product)),
      );
    }
  }

  void _delete() {
    final product = widget.existingProduct;
    if (product == null) return;

    showDialog<void>(
      context: context,
      builder: (_) => ConfirmationDialog(
        message:
            'This will permanently delete ${productDisplayName(product)} '
            'from your stock.',
        confirmLabel: 'Delete',
        onConfirm: () {
          if (!mounted) return;
          // The actual delete (with its own Undo window) happens back on
          // StockScreen, not here - this screen is about to be popped
          // since it's showing the very product being removed.
          Navigator.of(context).pop(product);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showMenuIcon: false,
        title: _isEditMode ? 'Edit Product' : 'Add Product',
      ),
      backgroundColor: AppTheme.background,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const _SectionLabel('BARCODE'),
            _buildBarcodeField(),
            if (_catalogueAutoFilled) ...[
              const SizedBox(height: 8),
              const _CatalogueBadge(),
            ] else if (_offAutoFilled) ...[
              const SizedBox(height: 8),
              const _OpenFoodFactsBadge(),
            ],
            const SizedBox(height: 24),
            const _SectionLabel('PRODUCT DETAILS'),
            TextFormField(
              controller: _nameController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Coca Cola',
              ),
              validator: (value) => (value == null || value.trim().length < 2)
                  ? 'Enter at least 2 characters'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _massController,
              decoration: const InputDecoration(
                labelText: 'Mass',
                hintText: 'e.g. 2L, 500g, 1kg',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Category', style: AppTheme.bodySubtitle),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            if (_selectedCategoryChip == 'Other') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _customCategoryController,
                decoration: const InputDecoration(hintText: 'Custom category'),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price *',
                      prefixText: 'R ',
                    ),
                    validator: (value) {
                      final v = double.tryParse(value?.trim() ?? '');
                      if (v == null || v <= 0) return 'Enter a valid price';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Cost Price',
                      prefixText: 'R ',
                      helperText: 'For margin tracking',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final cost = double.tryParse(text);
                      if (cost == null || cost <= 0) {
                        return 'Enter a valid cost price';
                      }
                      final selling = _sellingPriceValue;
                      if (selling != null && cost >= selling) {
                        return 'Must be less than selling price';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            _buildMarginDisplay(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(labelText: 'Stock Quantity *'),
              validator: (value) {
                final v = int.tryParse(value?.trim() ?? '');
                if (v == null || v < 0) return 'Enter a valid quantity';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lowStockController,
              keyboardType: TextInputType.number,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                labelText: 'Low Stock Alert',
                helperText: 'Alert when stock drops to this number',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final v = int.tryParse(text);
                if (v == null || v < 0) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _buildPreviewCard(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_canSave && !_saving) ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditMode ? 'Update Product' : 'Save Product'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            if (_isEditMode) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _saving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.logoutRed,
                    side: const BorderSide(color: AppTheme.logoutRed),
                  ),
                  child: const Text('Delete Product'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeField() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code, color: AppTheme.iconBorder),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'No barcode (optional)',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _rescan,
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: Text(
            _barcodeController.text.trim().isEmpty ? 'Scan' : 'Rescan',
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categoryOptions.map((option) {
        final isSelected = _selectedCategoryChip == option;
        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) => setState(() {
            _selectedCategoryChip = isSelected ? null : option;
            if (_selectedCategoryChip != 'Other') {
              _customCategoryController.clear();
            }
          }),
          selectedColor: AppTheme.primary,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: AppTheme.surface,
          side: BorderSide(color: isSelected ? AppTheme.primary : AppTheme.divider),
        );
      }).toList(),
    );
  }

  Widget _buildMarginDisplay() {
    final margin = profitMarginPercent(
      sellingPrice: _sellingPriceValue,
      costPrice: _costPriceValue,
    );
    if (margin == null) return const SizedBox.shrink();

    final color = marginColor(margin);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.trending_up, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              '${margin.toStringAsFixed(0)}% margin',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    final baseName = _nameController.text.trim();
    final mass = _massController.text.trim();
    final name = baseName.isEmpty
        ? 'Product name'
        : (mass.isEmpty ? baseName : '$baseName $mass');
    final category = _resolvedCategory();
    final price = _sellingPriceValue;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          ProductAvatar(name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (category != null)
                  Text(category, style: AppTheme.bodySubtitle),
              ],
            ),
          ),
          Text(
            price != null ? 'R${price.toStringAsFixed(2)}' : 'R0.00',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CatalogueBadge extends StatelessWidget {
  const _CatalogueBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle, size: 14, color: AppTheme.syncGreen),
        const SizedBox(width: 6),
        Text(
          'Auto-filled from PocketTill catalogue',
          style: TextStyle(fontSize: 12, color: AppTheme.syncGreen),
        ),
      ],
    );
  }
}

/// Shown instead of [_CatalogueBadge] when the autofill came from Open Food
/// Facts (Layer 2) rather than PocketTill's own verified catalogue - a
/// visual cue that this data still needs the cashier's own eyes on it
/// before saving, since it isn't verified the way an internal catalogue
/// match is.
class _OpenFoodFactsBadge extends StatelessWidget {
  const _OpenFoodFactsBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.info_outline, size: 14, color: AppTheme.syncAmber),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Details from a public source — please verify before saving',
            style: TextStyle(fontSize: 12, color: AppTheme.syncAmber),
          ),
        ),
      ],
    );
  }
}
