import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../core/sync/reachability_service.dart';
import '../../shared/repositories/store_config_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/friendly_error.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../settings/privacy_policy_screen.dart';
import '../settings/terms_of_service_screen.dart';
import '../shell/shell_screen.dart';
import 'otp_verification_screen.dart';

/// New store sign-up: store details, password, optional address. Requires a
/// live connection - creating a Supabase Auth user and `stores` row can't
/// happen offline.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  bool _storeNameTouched = false;
  bool _ownerNameTouched = false;
  bool _phoneTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;
  bool _agreedToTerms = false;

  late final _termsTapRecognizer = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
    );
  late final _privacyTapRecognizer = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );

  @override
  void initState() {
    super.initState();
    _storeNameController.addListener(_onChanged);
    _ownerNameController.addListener(_onChanged);
    _phoneController.addListener(_onChanged);
    _passwordController.addListener(_onChanged);
    _confirmPasswordController.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {
      _storeNameTouched = _storeNameTouched || _storeNameController.text.isNotEmpty;
      _ownerNameTouched = _ownerNameTouched || _ownerNameController.text.isNotEmpty;
      _phoneTouched = _phoneTouched || _phoneController.text.isNotEmpty;
      _passwordTouched = _passwordTouched || _passwordController.text.isNotEmpty;
      _confirmPasswordTouched =
          _confirmPasswordTouched || _confirmPasswordController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _termsTapRecognizer.dispose();
    _privacyTapRecognizer.dispose();
    super.dispose();
  }

  bool get _storeNameValid => _storeNameController.text.trim().length >= 2;
  bool get _ownerNameValid => _ownerNameController.text.trim().length >= 2;
  bool get _phoneValid =>
      _phoneController.text.replaceAll(RegExp(r'\s'), '').length >= 9;
  bool get _passwordValid => _passwordController.text.length >= 6;
  bool get _confirmPasswordValid =>
      _confirmPasswordController.text == _passwordController.text;

  bool get _canSubmit =>
      _storeNameValid &&
      _ownerNameValid &&
      _phoneValid &&
      _passwordValid &&
      _confirmPasswordValid &&
      _agreedToTerms;

  Future<void> _showNoInternetDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.wifi_off, size: 48, color: AppTheme.syncGrey),
        title: const Text('No Internet Connection'),
        content: const Text(
          'An internet connection is required to create your account. '
          'PocketTill works offline after setup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('User already registered')) {
      return 'This phone number is already registered. Try signing in instead.';
    }
    return friendlyErrorMessage(
      error,
      fallback: 'Could not create your account. Please try again or '
          'contact support.',
    );
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;

    setState(() => _submitting = true);

    // currentlyReachable alone is only as fresh as the last periodic ping
    // (or still the cold-start default false if none has completed yet) -
    // trusting it directly here false-positived as offline on a perfectly
    // good connection. ensureReachable() runs one fresh check before
    // believing a "false", so a real (rate-limited, worth not wasting)
    // OTP send isn't skipped over a stale reading.
    if (!await ref.read(reachabilityServiceProvider).ensureReachable()) {
      setState(() => _submitting = false);
      await _showNoInternetDialog();
      return;
    }

    final storeName = _storeNameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final ownerPhone = _phoneController.text.trim();
    final password = _passwordController.text;
    final address = _addressController.text.trim().isEmpty
        ? null
        : _addressController.text.trim();
    final formattedPhone = AuthService.formatPhone(_phoneController.text);

    try {
      if (await AuthService.phoneHasAccount(_phoneController.text)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'An account with this phone number already exists. '
              'Please login.',
            ),
            backgroundColor: AppTheme.logoutRed,
          ),
        );
        return;
      }

      await AuthService.requestOtp(_phoneController.text);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phone: formattedPhone,
            mode: OtpMode.registration,
            onVerified: (channel) async {
              await AuthService.setPassword(password);
              await AuthService.createStore(
                storeName: storeName,
                ownerName: ownerName,
                ownerPhone: ownerPhone,
                address: address,
                otpChannel: channel,
              );
              await ref.read(storeConfigProvider.notifier).refresh();
              if (!mounted) return;

              // Founding store status is earned later through usage, not
              // granted at signup - so registration always lands straight
              // in the app now (see ShellScreen's own qualification check).
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const ShellScreen()),
                (route) => false,
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(error)),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Create Account'),
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBetaBanner(),
            const SizedBox(height: 24),
            _sectionLabel('STORE DETAILS'),
            const SizedBox(height: 12),
            TextField(
              controller: _storeNameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.storefront_outlined),
                hintText: 'e.g. Mommy Spaza Shop',
                labelText: 'Store Name *',
                errorText: _storeNameTouched && !_storeNameValid
                    ? 'Enter at least 2 characters'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ownerNameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outlined),
                hintText: 'Your full name',
                labelText: 'Owner Name *',
                errorText: _ownerNameTouched && !_ownerNameValid
                    ? 'Enter at least 2 characters'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_outlined),
                hintText: '071 234 5678',
                labelText: 'Phone Number *',
                helperText: 'This will be your login number',
                errorText: _phoneTouched && !_phoneValid
                    ? 'Enter a valid phone number'
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('SET PASSWORD'),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                hintText: 'Minimum 6 characters',
                labelText: 'Password *',
                errorText: _passwordTouched && !_passwordValid
                    ? 'Enter at least 6 characters'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                hintText: 'Re-enter your password',
                labelText: 'Confirm Password *',
                errorText: _confirmPasswordTouched && !_confirmPasswordValid
                    ? 'Passwords do not match'
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            _sectionLabel('STORE LOCATION'),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
                hintText: 'Shop address (optional)',
                labelText: 'Address',
              ),
            ),
            const SizedBox(height: 24),
            _buildTermsCheckbox(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_canSubmit && !_submitting) ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBetaBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppTheme.drawerActiveBackground,
        border: Border(left: BorderSide(color: AppTheme.primary, width: 4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.star_outline, color: AppTheme.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Free during beta · First 100 stores get 50% lifetime discount',
              style: TextStyle(fontSize: 13, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    const linkStyle = TextStyle(
      color: AppTheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreedToTerms,
          onChanged: (value) =>
              setState(() => _agreedToTerms = value ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: linkStyle,
                    recognizer: _termsTapRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: linkStyle,
                    recognizer: _privacyTapRecognizer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
