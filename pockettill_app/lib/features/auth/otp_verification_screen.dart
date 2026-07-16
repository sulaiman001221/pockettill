import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';

/// What happens after the code is verified - both flows send/verify the
/// code identically; only [OtpVerificationScreen.onVerified] differs by
/// caller.
enum OtpMode { registration, passwordReset }

/// 6-digit WhatsApp OTP entry, shared by registration and password reset.
/// Calls [AuthService.verifyOtp] itself, then hands off to [onVerified] for
/// whatever the caller does next (set password + create store, or go to
/// [ResetPasswordScreen]) - [onVerified] is awaited so this screen's own
/// loading state covers that follow-up work too, not just the verify call.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.onVerified,
    required this.mode,
  });

  final String phone;
  final Future<void> Function() onVerified;
  final OtpMode mode;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const _digitCount = 6;
  static const _resendCooldownSeconds = 60;

  final _controllers = List.generate(_digitCount, (_) => TextEditingController());
  final _focusNodes = List.generate(_digitCount, (_) => FocusNode());

  bool _verifying = false;
  bool _resending = false;
  int _resendSecondsLeft = _resendCooldownSeconds;
  Timer? _resendTimer;
  OtpChannel _channel = OtpChannel.whatsapp;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _digitCount - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_code.length == _digitCount) {
      FocusScope.of(context).unfocus();
      _verify();
    }
  }

  void _clearCode() {
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {});
    _focusNodes.first.requestFocus();
  }

  Future<void> _verify() async {
    if (_verifying || _code.length != _digitCount) return;
    setState(() => _verifying = true);

    // Verifying the code and running the caller's follow-up work (set
    // password, create the store, etc.) are kept in separate try blocks -
    // a failure in the follow-up isn't the code's fault, so it shouldn't
    // clear the input or blame it on an invalid/expired OTP.
    try {
      await AuthService.verifyOtp(phone: widget.phone, token: _code);
    } catch (_) {
      _clearCode();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid or expired code. Check your WhatsApp and try again.',
            ),
            backgroundColor: AppTheme.logoutRed,
          ),
        );
        setState(() => _verifying = false);
      }
      return;
    }

    try {
      await widget.onVerified();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppTheme.logoutRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSecondsLeft > 0) return;
    setState(() => _resending = true);
    try {
      await AuthService.requestOtp(widget.phone, channel: _channel);
      _startResendCooldown();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resend code. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Fallback for stores without WhatsApp (lost account, never had one, or
  /// just prefer SMS) - not gated by the resend cooldown, since a user who
  /// already knows they have no WhatsApp shouldn't have to wait it out
  /// first.
  Future<void> _sendViaSms() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await AuthService.requestOtp(widget.phone, channel: OtpChannel.sms);
      setState(() => _channel = OtpChannel.sms);
      _startResendCooldown();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send code via SMS. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: false, title: 'Verify Phone'),
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            Icon(
              _channel == OtpChannel.whatsapp ? Icons.message : Icons.sms_outlined,
              size: 64,
              color: _channel == OtpChannel.whatsapp
                  ? const Color(0xFF25D366)
                  : AppTheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              _channel == OtpChannel.whatsapp
                  ? 'Check your WhatsApp'
                  : 'Check your SMS messages',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to\n${widget.phone}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _digitCount,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _DigitBox(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    onChanged: (value) => _onDigitChanged(index, value),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive a code? ",
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                _resendSecondsLeft > 0
                    ? Text(
                        'Resend in 0:${_resendSecondsLeft.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : GestureDetector(
                        onTap: _resend,
                        child: const Text(
                          'Resend',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
            if (_channel == OtpChannel.whatsapp) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _resending ? null : _sendViaSms,
                child: const Text(
                  'Not on WhatsApp? Send code via SMS instead',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_code.length == _digitCount && !_verifying)
                    ? _verify
                    : null,
                child: _verifying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Verify'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitBox extends StatelessWidget {
  const _DigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([focusNode, controller]),
      builder: (context, _) {
        final isFilled = controller.text.isNotEmpty;
        return SizedBox(
          width: 48,
          height: 56,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: isFilled ? AppTheme.drawerActiveBackground : AppTheme.surface,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}
