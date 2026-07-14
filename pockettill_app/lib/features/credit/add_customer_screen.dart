import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import 'customer_added_success_screen.dart';

/// Add/edit customer form. Create mode when [existingCustomer] is null, edit
/// mode otherwise. All writes go through [creditRepositoryProvider].
class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key, this.existingCustomer});

  final CreditCustomer? existingCustomer;

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _creditLimitController = TextEditingController();
  bool _saving = false;
  bool _nameTouched = false;

  bool get _isEditMode => widget.existingCustomer != null;

  /// Only flags an error once the user has actually interacted with the
  /// field and then left it empty - never on first load, and clears the
  /// instant they type anything.
  bool get _nameHasError => _nameTouched && _nameController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCustomer;
    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone ?? '';
      _creditLimitController.text = existing.creditLimit?.toStringAsFixed(2) ?? '';
    }
    _nameController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() => _nameTouched = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().length >= 2;

  /// Checks the customer name against every other customer, excluding the
  /// one being edited - names must be unique so a seller can always tell
  /// customers apart on the list.
  Future<String?> _findDuplicateNameError() async {
    final repo = ref.read(creditRepositoryProvider);
    final currentUuid = widget.existingCustomer?.uuid;
    final normalizedName = _nameController.text.trim().toLowerCase();

    final all = await repo.getAll();
    final hasDuplicate = all.any(
      (c) => c.uuid != currentUuid && c.name.trim().toLowerCase() == normalizedName,
    );
    if (hasDuplicate) return 'A customer with this name already exists';
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final duplicateError = await _findDuplicateNameError();
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

    final phone = _phoneController.text.trim();
    final limitText = _creditLimitController.text.trim();

    final customer = widget.existingCustomer ?? (CreditCustomer()..uuid = '' ..balance = 0);
    customer
      ..name = _nameController.text.trim()
      ..phone = phone.isEmpty ? null : phone
      ..creditLimit = limitText.isEmpty ? null : double.tryParse(limitText);

    await ref.read(creditRepositoryProvider).saveCustomer(customer);

    if (!mounted) return;
    setState(() => _saving = false);

    if (_isEditMode) {
      Navigator.of(context).pop('updated');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerAddedSuccessScreen(customer: customer),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showMenuIcon: false,
        title: _isEditMode ? 'Edit Customer' : 'Add New Customer',
      ),
      backgroundColor: AppTheme.background,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 24),
            _fieldLabelRow('Full Name', required: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline),
                hintText: 'Enter customer name',
                helperText: 'Required - used to identify this customer',
                errorText: _nameHasError ? 'Full name is required' : null,
              ),
              validator: (value) => (value == null || value.trim().length < 2)
                  ? 'Enter at least 2 characters'
                  : null,
            ),
            const SizedBox(height: 20),
            _fieldLabelRow('Phone Number', optional: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined),
                prefixText: '+27  ',
                hintText: 'e.g. 071 234 5678',
              ),
              validator: (value) {
                final digits = value?.trim() ?? '';
                if (digits.isEmpty) return null;
                if (digits.length != 10) return 'Enter a valid 10-digit phone number';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _fieldLabelRow('Credit Limit', optional: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _creditLimitController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: 'R ',
                hintText: '0.00',
                helperText: 'Maximum amount this customer can owe',
              ),
            ),
            const SizedBox(height: 20),
            _buildInfoCard(),
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_alt_1, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(_isEditMode ? 'Update Customer' : 'Save Customer'),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabelRow(String label, {bool required = false, bool optional = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        if (required)
          const Text(' *', style: TextStyle(color: AppTheme.logoutRed)),
        const Spacer(),
        if (optional)
          const Text(
            'Optional',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isEditMode ? Icons.edit_outlined : Icons.person_add_alt_1,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Edit Customer' : 'New Customer Profile',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditMode
                      ? "Update this customer's details below."
                      : 'Fill in the details below to add them to your customer list.',
                  style: AppTheme.bodySubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Customer details can be updated anytime from your Customers '
              'tab. A phone number helps with payment reminders.',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
