import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/catalogue/open_food_facts_service.dart';
import '../../core/storage/product_image_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../core/sync/reachability_service.dart';
import '../../core/sync/realtime_data_sync_service.dart';
import '../../shared/models/product.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import 'barcode_scanner_screen.dart';
import 'product_success_screen.dart';
import 'stock_ui.dart';

const _uuid = Uuid();

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
  final _stockController = TextEditingController(text: '0');
  final _lowStockController = TextEditingController(text: '5');

  String? _selectedCategoryChip;
  bool _catalogueAutoFilled = false;
  bool _offAutoFilled = false;
  // Auto-filled image from either lookup layer (own catalogue or Open Food
  // Facts) - applied on save unless the owner has since uploaded their own
  // photo, which always wins (see _save).
  String? _autoFilledImageUrl;
  // The image already saved on this product before this screen opened
  // (edit mode only) - kept separate from _autoFilledImageUrl so a fresh
  // barcode re-lookup can never silently clobber a photo the owner already
  // took, only an explicit pick or removal can.
  String? _existingImageUrl;
  // The product exactly as this screen opened it (edit mode only). Saving
  // sends only what differs from this - never a field the person didn't
  // touch, and the stock as a change from this quantity rather than an
  // absolute number - so anything another device (or a sale) changed while
  // the form was open isn't overwritten by saving it.
  Product? _initialProduct;
  File? _pickedImageFile;
  bool _imageRemoved = false;
  bool _saving = false;
  // Suggestions for the "Other" category free-text field, drawn from the
  // verified catalogue so a custom category has a chance of matching one
  // that already exists rather than fragmenting into near-duplicates (e.g.
  // "Household" vs "Household Items"). The field stays free-text either
  // way - these are suggestions, not a constraint.
  List<String> _verifiedCategories = [];

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
      _initialProduct = Product()
        ..uuid = existing.uuid
        ..barcode = existing.barcode
        ..name = existing.name
        ..mass = existing.mass
        ..category = existing.category
        ..unit = existing.unit
        ..price = existing.price
        ..costPrice = existing.costPrice
        ..stock = existing.stock
        ..lowStockThreshold = existing.lowStockThreshold
        ..imageUrl = existing.imageUrl
        ..createdAt = existing.createdAt;
      _lowStockController.text = '${existing.lowStockThreshold}';
      _existingImageUrl = existing.imageUrl;
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

    _loadVerifiedCategories();
  }

  Future<void> _loadVerifiedCategories() async {
    try {
      final categories = await ref
          .read(catalogueBrowseRepositoryProvider)
          .fetchCategories();
      if (!mounted) return;
      setState(() {
        _verifiedCategories =
            categories.map((c) => c.category).where((c) => c != 'Uncategorised').toList()
              ..sort();
      });
    } catch (_) {
      // Offline, or the request failed - the field still works as plain
      // free text without suggestions.
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

  /// Verified categories matching what's typed so far, for the tappable
  /// suggestion chips under the "Other" field - up to 6 so the chips never
  /// crowd out the rest of the form. Deliberately plain chips rather than
  /// Flutter's `Autocomplete` widget: `Autocomplete` inserts an overlay
  /// entry that Flutter has a long-standing bug with when its route is
  /// popped while the field is still active (crashes with
  /// `_children.contains(child)` in framework.dart) - found 2026-09-05 via
  /// exactly that crash when backing out of this screen from the catalogue
  /// scan-not-found flow.
  List<String> get _matchingVerifiedCategories {
    final query = _customCategoryController.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? _verifiedCategories
        : _verifiedCategories.where((c) => c.toLowerCase().contains(query));
    return matches.take(6).toList();
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

  /// Layer 1. Returns whether a match was found and applied.
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
        _autoFilledImageUrl = row['image_url'] as String?;
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

    // Open Food Facts can return status 1 ("found") for a barcode whose
    // entry has no actual product data - a stub with just an ecoscore tag
    // or similar, nothing usable. That must not be shown as "sourced from
    // a public source" when nothing was actually sourced - found
    // 2026-08-23 from exactly that badge appearing on an unfillable
    // product.
    final hasUsefulData = product.name != null || product.mass != null;
    if (!hasUsefulData) return;

    setState(() {
      if (product.name != null) _nameController.text = product.name!;
      if (product.mass != null) _massController.text = product.mass!;
      _autoFilledImageUrl = product.imageUrl;
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

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await ProductImageService.pickImage(source);
    if (file == null || !mounted) return;
    setState(() {
      _pickedImageFile = file;
      _imageRemoved = false;
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImageFile = null;
      _imageRemoved = true;
    });
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

  /// Resolves what [product]'s `imageUrl` should be for this save, uploading
  /// a freshly-picked photo or deleting a removed one along the way. A
  /// manual pick or explicit removal always wins; short of either of those,
  /// an existing image is preserved as-is (never silently replaced by a
  /// fresh autofill - see [_existingImageUrl]'s doc comment), and autofill
  /// only applies when there was never an image to begin with. Returns a
  /// user-facing error message on failure, or null on success.
  Future<String?> _resolveImageUrl(Product product) async {
    final picked = _pickedImageFile;
    if (picked != null) {
      final storeId = (await ref.read(storeConfigRepositoryProvider).get())?.storeId;
      if (storeId == null || storeId.isEmpty) {
        return 'Could not upload photo — no store found. Try again.';
      }
      try {
        product.imageUrl = await ProductImageService.uploadProductImage(
          source: picked,
          storeId: storeId,
          productUuid: product.uuid,
        );
      } catch (_) {
        return 'Could not upload photo — check your connection and try again.';
      }
      return null;
    }

    if (_imageRemoved) {
      final storeId = (await ref.read(storeConfigRepositoryProvider).get())?.storeId;
      if (storeId != null && storeId.isNotEmpty) {
        await ProductImageService.deleteProductImage(
          storeId: storeId,
          productUuid: product.uuid,
        );
      }
      product.imageUrl = null;
      return null;
    }

    product.imageUrl = _existingImageUrl ?? _autoFilledImageUrl;
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

    final product =
        widget.existingProduct ?? (Product()..uuid = _uuid.v4());
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

    final imageError = await _resolveImageUrl(product);
    if (imageError != null) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(imageError), backgroundColor: AppTheme.logoutRed),
      );
      return;
    }

    await ref
        .read(productRepositoryProvider)
        .save(product, initial: _initialProduct);

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
    // If another device deletes the exact product this screen is editing,
    // there's nothing left to save against - leave instead of letting the
    // owner submit an edit to a row that no longer exists.
    final editingUuid = widget.existingProduct?.uuid;
    if (editingUuid != null) {
      ref.listen(productDeletedProvider, (_, next) {
        if (next.valueOrNull != editingUuid || !mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This product has been removed')),
        );
        Navigator.of(context).pop();
      });
    }

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
            const _SectionLabel('PHOTO'),
            _buildImagePicker(),
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
                decoration: const InputDecoration(
                  hintText: 'Custom category',
                  helperText: 'Pick an existing category if one matches',
                ),
              ),
              if (_matchingVerifiedCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _matchingVerifiedCategories
                      .map(
                        (category) => ActionChip(
                          label: Text(category),
                          onPressed: () => setState(() {
                            _customCategoryController.text = category;
                          }),
                          backgroundColor: AppTheme.surface,
                          side: const BorderSide(color: AppTheme.divider),
                          labelStyle: const TextStyle(color: AppTheme.textPrimary),
                        ),
                      )
                      .toList(),
                ),
              ],
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

  Widget _buildImagePicker() {
    final picked = _pickedImageFile;
    final networkUrl = (picked == null && !_imageRemoved)
        ? (_existingImageUrl ?? _autoFilledImageUrl)
        : null;
    final hasImage = picked != null || networkUrl != null;
    // Only meaningful for the product's own original image - a fresh
    // catalogue/OFF autofill URL was never cached under this barcode, and
    // this stops applying the instant a different photo is picked or the
    // current one removed anyway (networkUrl becomes null either way).
    final cachedImagePath = networkUrl != null && networkUrl == _existingImageUrl
        ? widget.existingProduct?.cachedImagePath
        : null;
    final barcode = _barcodeController.text.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _saving ? null : _pickImage,
          child: Container(
            width: 88,
            height: 88,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: picked != null
                ? Image.file(picked, fit: BoxFit.cover)
                : networkUrl != null
                ? CachedProductImage(
                    // Falls back to the URL itself only for the rare
                    // barcode-less product - ImageCacheService's own cache
                    // key everywhere else is always the barcode (see
                    // CachedProductImage's other call sites), so this stays
                    // consistent with whatever the Stock list already
                    // cached for the same product.
                    cacheKey: barcode.isNotEmpty ? barcode : networkUrl,
                    imageUrl: networkUrl,
                    cachedImagePath: cachedImagePath,
                    fit: BoxFit.cover,
                    placeholder: const Icon(
                      Icons.image_not_supported_outlined,
                      color: AppTheme.iconBorder,
                    ),
                    loadingPlaceholder: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppTheme.iconBorder,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a photo (optional)', style: AppTheme.bodySubtitle),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _pickImage,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(hasImage ? 'Change Photo' : 'Take or Choose Photo'),
              ),
              if (hasImage)
                TextButton(
                  onPressed: _saving ? null : _removeImage,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.logoutRed,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Remove Photo'),
                ),
            ],
          ),
        ),
      ],
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
          ProductAvatar(
            name: name,
            // The freshly-picked local file isn't shown here - it's already
            // visible in the photo picker above, and ProductAvatar only
            // deals in network URLs (every other call site's Product.imageUrl
            // already is one).
            imageUrl: _imageRemoved ? null : (_existingImageUrl ?? _autoFilledImageUrl),
          ),
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
