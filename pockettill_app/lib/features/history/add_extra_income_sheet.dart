import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/models/extra_income.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';

/// Bottom sheet for recording one-off income that isn't a regular sale -
/// e.g. airtime vouchers or electricity tokens sold outside checkout. Pops
/// `true` once saved/updated/deleted so the caller knows to refresh, or
/// `null`/`false` if cancelled.
///
/// Pass [existing] to edit (and optionally delete) an entry already saved -
/// its fields pre-fill the form and the primary button reads "Update"
/// instead of "Save". Leave it null for the normal "add new" flow.
class AddExtraIncomeSheet extends ConsumerStatefulWidget {
  const AddExtraIncomeSheet({super.key, this.existing});

  final ExtraIncome? existing;

  @override
  ConsumerState<AddExtraIncomeSheet> createState() =>
      _AddExtraIncomeSheetState();
}

class _AddExtraIncomeSheetState extends ConsumerState<AddExtraIncomeSheet> {
  late final _amountController = TextEditingController(
    text: widget.existing == null
        ? ''
        : _stripTrailingZeros(widget.existing!.amount),
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late DateTime _date = widget.existing?.createdAt ?? DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  double? get _amount => double.tryParse(_amountController.text.trim());

  bool get _canSave =>
      (_amount ?? 0) > 0 && _descriptionController.text.trim().isNotEmpty;

  static String _stripTrailingZeros(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final repo = ref.read(extraIncomeRepositoryProvider);
    if (_isEditing) {
      await repo.update(
        uuid: widget.existing!.uuid,
        amount: _amount!,
        description: _descriptionController.text.trim(),
        date: _date,
      );
    } else {
      await repo.add(
        amount: _amount!,
        description: _descriptionController.text.trim(),
        date: _date,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Extra Income?'),
        content: const Text(
          'This entry will be removed from Sales History and today\'s '
          'totals. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    await ref.read(extraIncomeRepositoryProvider).delete(widget.existing!.uuid);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
            Icon(
              _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
              size: 48,
              color: AppTheme.syncGreen,
            ),
            const SizedBox(height: 12),
            Text(
              _isEditing ? 'Edit Extra Income' : 'Add Extra Income',
              textAlign: TextAlign.center,
              style: AppTheme.mainTitle,
            ),
            const SizedBox(height: 8),
            const Text(
              'Record income that isn\'t a regular sale - like airtime or '
              'electricity tokens.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySubtitle,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              autofocus: !_isEditing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount *',
                prefixText: 'R ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'e.g. Airtime',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(DateFormat('d MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
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
                    : Text(_isEditing ? 'Update' : 'Save'),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _saving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.logoutRed,
                    side: const BorderSide(color: AppTheme.logoutRed),
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
