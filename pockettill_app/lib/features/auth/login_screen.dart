import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/sync/reachability_service.dart';
import '../../shared/repositories/store_config_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/contact_support.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../shell/shell_screen.dart';
import 'otp_verification_screen.dart';
import 'reset_password_screen.dart';

/// Sign-in for an existing store, on this device or a fresh install.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.showKickedByOtherDeviceBanner = false});

  /// Set when [ShellScreen] routed here specifically because this device's
  /// session was revoked by a newer login elsewhere - shows a banner
  /// explaining why, instead of leaving the user to wonder why they were
  /// signed out. Never set for a manual logout or a natural session expiry,
  /// which land here (or on WelcomeScreen) with no banner as before.
  final bool showKickedByOtherDeviceBanner;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onFieldsChanged);
    _passwordController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    // Only to repaint the Sign In button's enabled state - no field-level
    // validation beyond "something is typed", since the server is the
    // actual source of truth for whether phone+password are correct.
    setState(() {});
  }

  bool get _canSubmit =>
      _phoneController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Shown only from the forgot-password sheet now - login itself makes its
  /// own real network call rather than pre-checking reachability (see
  /// [_submit]), so this dialog's wording is reset-specific rather than
  /// generic "sign in" text that no longer applies to where it's used.
  Future<void> _showNoInternetDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.wifi_off, size: 48, color: AppTheme.syncGrey),
        title: const Text('No Internet Connection'),
        content: const Text(
          'An internet connection is required to reset your password. '
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

  Future<void> _submit() async {
    if (_submitting || !_canSubmit) return;

    // No pre-emptive reachability check here (unlike registration/reset,
    // which start an OTP flow that's wasteful to kick off while offline):
    // ReachabilityService.currentlyReachable only flips true once its
    // periodic ping confirms it, so checking it right when the app opens
    // straight to Login (e.g. after logging out) can false-positive as
    // "offline" even with a perfectly good connection. Login already makes
    // its own real network call, so let that call itself be the
    // reachability check.
    setState(() => _submitting = true);
    try {
      final result = await AuthService.login(
        phone: _phoneController.text,
        password: _passwordController.text,
      );

      if (result.needsDeviceVerification) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              phone: result.phone!,
              mode: OtpMode.newDeviceVerification,
              initialChannel: result.otpChannel!,
              onVerified: (_) async {
                await AuthService.completeNewDeviceLogin(result);
                await ref.read(storeConfigProvider.notifier).refresh();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ShellScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        );
        return;
      }

      await ref.read(storeConfigProvider.notifier).refresh();
      if (!mounted) return;
      // pushAndRemoveUntil, not pushReplacement - Login was pushed on top
      // of WelcomeScreen, and pushReplacement only swaps out the topmost
      // route, leaving WelcomeScreen stranded underneath. Every "Return
      // Home" success screen (add product, complete sale, etc.) calls
      // Navigator.popUntil((route) => route.isFirst) to get back to
      // ShellScreen - with Welcome left in the stack, that popped all the
      // way back to Welcome/Login instead of stopping at ShellScreen.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
        (route) => false,
      );
    } on AuthRetryableFetchException catch (_) {
      // A network-level failure (offline, timeout, DNS, etc.) - this is a
      // *subtype* of AuthException, so it must be caught before the
      // broader `on AuthException` below, or a genuinely offline login
      // gets mislabeled as a wrong password.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connection failed. Please check your internet and try again.',
          ),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
    } on AuthException catch (_) {
      // Never reveal which field was wrong - just phone-or-password.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect phone number or password'),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
    } catch (_) {
      // Anything else unexpected - same connection-failure wording, since
      // it's far more likely than a credentials issue at this point.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connection failed. Please check your internet and try again.',
          ),
          backgroundColor: AppTheme.logoutRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildKickedByOtherDeviceBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.logoutRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.logoutRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.logoutRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Signed Out',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.logoutRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You have been signed out because your account was accessed '
            "from another device. If this wasn't you, contact support "
            'immediately.',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showContactSupportOptions(context),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Contact Support'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.logoutRed,
                side: const BorderSide(color: AppTheme.logoutRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showForgotPasswordSheet() {
    final phoneController = TextEditingController();
    var sending = false;
    // Shown inline in the sheet rather than as a SnackBar - a SnackBar
    // raised while this modal sheet is still open ends up hidden behind
    // it, which read as "no error at all" when the phone had no account.
    String? errorText;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reset Password', style: AppTheme.mainTitle),
              const SizedBox(height: 12),
              const Text(
                "Enter your phone number and we'll send a code over "
                'WhatsApp to verify it\'s you.',
                style: AppTheme.bodySubtitle,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone_outlined),
                  hintText: '071 234 5678',
                  labelText: 'Phone Number',
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) setSheetState(() => errorText = null);
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: sending
                      ? null
                      : () async {
                          setSheetState(() {
                            sending = true;
                            errorText = null;
                          });
                          if (!await ref
                              .read(reachabilityServiceProvider)
                              .ensureReachable()) {
                            setSheetState(() => sending = false);
                            await _showNoInternetDialog();
                            return;
                          }
                          try {
                            final formatted = AuthService.formatPhone(
                              phoneController.text,
                            );

                            if (!await AuthService.phoneHasAccount(
                              phoneController.text,
                            )) {
                              setSheetState(() {
                                sending = false;
                                errorText =
                                    'No account found with this number. '
                                    'Please sign up.';
                              });
                              return;
                            }

                            await AuthService.requestOtp(phoneController.text);
                            if (!mounted) return;
                            Navigator.of(sheetContext).pop();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OtpVerificationScreen(
                                  phone: formatted,
                                  mode: OtpMode.passwordReset,
                                  onVerified: (_) async {
                                    if (!mounted) return;
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ResetPasswordScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          } catch (_) {
                            setSheetState(() {
                              sending = false;
                              errorText = 'Could not send code. Please try again.';
                            });
                          }
                        },
                  child: sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Code'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Sign In'),
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          children: [
            Image.asset('assets/images/pockettill_icon.png', height: 32),
            const SizedBox(height: 16),
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in to your PocketTill account',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            if (widget.showKickedByOtherDeviceBanner)
              _buildKickedByOtherDeviceBanner(),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '071 234 5678',
                labelText: 'Phone Number',
              ),
            ),
            const SizedBox(height: 16),
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
                hintText: 'Your password',
                labelText: 'Password',
              ),
            ),
            const SizedBox(height: 24),
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
                    : const Text('Sign In'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _showForgotPasswordSheet,
              child: const Text(
                'Forgot your password?',
                style: TextStyle(color: AppTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
