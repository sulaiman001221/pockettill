import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/friendly_error.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import 'welcome_screen.dart';

const String _supportWhatsAppNumber = '27625631968';

/// What happens after the code is verified - all three modes send/verify
/// the code identically; only [OtpVerificationScreen.onVerified] differs by
/// caller, and [OtpMode.newDeviceVerification] additionally changes the
/// screen's copy and blocks casually backing out of it (see
/// [_OtpVerificationScreenState._confirmAbandon]).
enum OtpMode { registration, passwordReset, newDeviceVerification }

/// 6-digit OTP entry, shared by registration, password reset, and new-device
/// login verification. Calls [AuthService.verifyOtp] itself, then hands off
/// to [onVerified] for whatever the caller does next - [onVerified] is
/// awaited so this screen's own loading state covers that follow-up work
/// too, not just the verify call. [onVerified] receives the channel the
/// code actually ended up being sent on (WhatsApp unless the user switched
/// to SMS), which registration needs to persist as the store's OTP
/// preference for later new-device logins.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.onVerified,
    required this.mode,
    this.initialChannel = OtpChannel.whatsapp,
  });

  final String phone;
  final Future<void> Function(OtpChannel channel) onVerified;
  final OtpMode mode;

  /// Which channel the code was actually sent on before this screen opened
  /// - matters for [OtpMode.newDeviceVerification], where the store's saved
  /// preference (possibly SMS) decides it, rather than always defaulting to
  /// WhatsApp the way a fresh registration does.
  final OtpChannel initialChannel;

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
  late OtpChannel _channel;

  bool get _isNewDeviceMode => widget.mode == OtpMode.newDeviceVerification;

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel;
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
    // A paste into one box isn't stopped at 1 character by `maxLength` (see
    // MaxLengthEnforcement.none on _DigitBox) - it lands here as the full
    // pasted string instead, so it can be spread across this box and the
    // ones after it rather than only filling the one it landed in.
    if (value.length > 1) {
      _distributePaste(index, value);
      return;
    }
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

  void _distributePaste(int index, String digits) {
    for (var i = 0; i < digits.length && index + i < _digitCount; i++) {
      _controllers[index + i].text = digits[i];
    }
    setState(() {});
    final lastFilledIndex = (index + digits.length - 1).clamp(0, _digitCount - 1);
    if (lastFilledIndex < _digitCount - 1) {
      _focusNodes[lastFilledIndex + 1].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
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
        final source = _channel == OtpChannel.whatsapp ? 'WhatsApp' : 'SMS';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid or expired code. Check your $source and try again.'),
            backgroundColor: AppTheme.logoutRed,
          ),
        );
        setState(() => _verifying = false);
      }
      return;
    }

    try {
      await widget.onVerified(_channel);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                error,
                fallback: 'Could not complete verification. Please try '
                    'again or contact support.',
              ),
            ),
            backgroundColor: AppTheme.logoutRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _contactSupport() async {
    final uri = Uri.parse('https://wa.me/$_supportWhatsAppNumber');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// [AuthService.login]'s password check already created a live session on
  /// this device before this screen even opened - simply backing out here
  /// (system back gesture, the app bar's back arrow, or killing the app)
  /// must not leave that session usable, or the new-device check it's
  /// meant to gate would be pointless. Confirms with the user, then revokes
  /// the session server-side before letting the pop through.
  Future<void> _confirmAbandon() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel verification?'),
        content: const Text(
          "You'll need to sign in again to access your account.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel Verification'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await AuthService.abandonNewDeviceVerification();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
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

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      // CustomAppBar's back arrow calls Navigator.pop() directly, which
      // bypasses PopScope entirely (PopScope only gates system back
      // gestures/buttons, not an explicit in-app pop() call) - so new-device
      // mode uses a plain title bar with no leading icon at all, rather than
      // relying on PopScope to catch a tap that would never reach it.
      appBar: _isNewDeviceMode
          ? AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              toolbarHeight: 72,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: const Text(
                'Verify Phone',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            )
          : const CustomAppBar(showMenuIcon: false, title: 'Verify Phone'),
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            if (!_isNewDeviceMode)
              // Generic, not channel-specific - the code could land via
              // either WhatsApp or SMS depending on how Twilio's delivery
              // falls back, so there's no single channel this icon can
              // commit to.
              const Icon(
                Icons.chat_outlined,
                size: 64,
                color: AppTheme.primary,
              ),
            if (!_isNewDeviceMode) const SizedBox(height: 20),
            Text(
              _isNewDeviceMode ? "Verify It's You" : 'Check your messages',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isNewDeviceMode
                  ? "To confirm it's you, enter the 6-digit code sent to "
                        '${widget.phone}'
                  : "You'll receive a 6-digit code via WhatsApp or SMS\n"
                        '${widget.phone}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            if (_isNewDeviceMode) ...[
              const SizedBox(height: 4),
              const Text(
                'This is only required once per device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
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
            const SizedBox(height: 20),
            // Subtle, not a prominent CTA - deliberately smaller/quieter
            // than the resend/SMS-fallback rows above it.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Need help? ',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                GestureDetector(
                  onTap: _contactSupport,
                  child: const Text(
                    'Contact Support',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
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

    if (!_isNewDeviceMode) return scaffold;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmAbandon();
      },
      child: scaffold,
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
            // No length limit here (and no maxLengthEnforcement to clip
            // it) - a multi-digit paste needs to reach onChanged whole so
            // the screen can spread it across the other boxes; each box's
            // own controller is truncated back to one digit right after,
            // in _distributePaste.
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
