import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../../shared/repositories/store_config_provider.dart';
import '../shell/shell_screen.dart';
import 'otp_verification_screen.dart';
import 'welcome_screen.dart';

/// The app's entry screen: shows the logo briefly while deciding where to
/// route. A valid session normally goes straight into the app (even
/// offline, since PocketTill works fully offline once set up); no session
/// always lands on WelcomeScreen. Login and Register both make their own
/// "no internet" check when actually submitting, so there's no need for a
/// separate connectivity gate here.
///
/// The one exception: a valid session whose device no longer matches the
/// store's trusted device (see [AuthService.checkDeviceTrust]) is routed
/// through the same new-device OTP challenge login uses, instead of
/// straight into the app - this is what catches a new-device verification
/// that was abandoned by killing the app rather than explicitly cancelling
/// it, since that path never runs [AuthService.abandonNewDeviceVerification].
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _route();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final loggedIn = await AuthService.isLoggedIn;
    if (!mounted) return;

    if (!loggedIn) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      return;
    }

    final verification = await AuthService.checkDeviceTrust();
    if (!mounted) return;

    if (verification != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phone: verification.phone!,
            mode: OtpMode.newDeviceVerification,
            initialChannel: verification.otpChannel!,
            onVerified: (_) async {
              await AuthService.completeNewDeviceLogin(verification);
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

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5170FF),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Image.asset(
            'assets/images/Pockettill_white_logo.png',
            height: 64,
          ),
        ),
      ),
    );
  }
}
