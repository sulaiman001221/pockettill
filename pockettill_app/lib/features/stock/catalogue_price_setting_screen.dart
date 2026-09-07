import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/catalogue_browse_repository.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';

/// Set a selling price for each selected catalogue item before it's added
/// to stock, or skip and price everything later from the normal Stock list.
///
/// Nothing is written to Isar/Supabase until the user taps "Save Prices" or
/// "Set prices later" - backing out via the app bar's back arrow cancels
/// the whole import instead of silently adding unpriced products, which is
/// exactly the bug this screen used to have when the caller imported
/// eagerly before this screen even opened.
///
/// Pops with the number of products actually imported, or null if the user
/// backed out without confirming either action.
class CataloguePriceSettingScreen extends ConsumerStatefulWidget {
  const CataloguePriceSettingScreen({super.key, required this.items});

  final List<CatalogueBrowseItem> items;

  @override
  ConsumerState<CataloguePriceSettingScreen> createState() =>
      _CataloguePriceSettingScreenState();
}

class _CataloguePriceSettingScreenState
    extends ConsumerState<CataloguePriceSettingScreen> {
  late final Map<String, TextEditingController> _controllers = {
    for (final item in widget.items) item.barcode: TextEditingController(),
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _confirm({required bool withPrices}) async {
    setState(() => _saving = true);

    Map<String, double>? prices;
    if (withPrices) {
      prices = {};
      for (final item in widget.items) {
        final price = double.tryParse(_controllers[item.barcode]!.text.trim());
        if (price != null && price > 0) prices[item.barcode] = price;
      }
    }

    final imported = await ref
        .read(productRepositoryProvider)
        .importFromCatalogue(widget.items, prices: prices);

    if (!mounted) return;
    Navigator.of(context).pop(imported.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Set Prices'),
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              '${widget.items.length} product${widget.items.length == 1 ? '' : 's'} selected - set a selling price for each, or set prices later.',
              style: AppTheme.bodySubtitle,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final subtitle = (item.mass ?? '').isEmpty
                    ? item.name
                    : '${item.name} ${item.mass}';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _controllers[item.barcode],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            prefixText: 'R ',
                            hintText: '0.00',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _confirm(withPrices: true),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Prices'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => _confirm(withPrices: false),
                  child: const Text('Set prices later'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
