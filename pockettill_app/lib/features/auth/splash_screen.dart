import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/auth_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/repositories/store_config_provider.dart';
import '../../shared/theme/system_ui.dart';
import '../shell/shell_screen.dart';
import 'login_screen.dart';
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
    // Imperative, not AnnotatedRegion - see the class doc comment on
    // darkScreenStatusBar for why. Set here (not build()) so it's applied
    // exactly once, and reverted in dispose() exactly once, regardless of
    // how many times build() runs during the fade animation.
    SystemChrome.setSystemUIOverlayStyle(darkScreenStatusBar);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _route();
  }

  Future<void> _route() async {
    // Waits for whichever takes longer: the minimum splash display time (so
    // the logo doesn't just flash by), or Supabase actually finishing
    // restoring any persisted session - see
    // SupabaseService.waitForSessionRestore. Checking [AuthService.isLoggedIn]
    // against a session that hasn't finished loading yet is what used to
    // cause the login screen to flash briefly on an already-logged-in
    // device, worse on slower phones where restoration takes longer than a
    // fixed delay alone could cover.
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      SupabaseService.waitForSessionRestore(),
    ]);
    if (!mounted) return;

    final loggedIn = await AuthService.isLoggedIn;
    if (!mounted) return;

    if (!loggedIn) {
      // A session that existed and then stopped working (rather than never
      // existing) may well have been revoked by a login on another device -
      // the same case ShellScreen explains with a banner when the app is
      // already open. Without this, being kicked while the app was *closed*
      // would drop the user on a bare Welcome screen with no explanation,
      // which is exactly what that banner exists to avoid.
      final config = await ref.read(storeConfigRepositoryProvider).get();
      if (!mounted) return;

      if (config != null && config.isLoggedIn && config.storeId.isNotEmpty) {
        final kickedByNewDevice = await AuthService.wasSignedOutByNewDevice(
          storeId: config.storeId,
          deviceId: config.deviceId,
        );
        if (!mounted) return;

        if (kickedByNewDevice) {
          config.isLoggedIn = false;
          await ref.read(storeConfigRepositoryProvider).save(config);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) =>
                  const LoginScreen(showKickedByOtherDeviceBanner: true),
            ),
          );
          return;
        }
      }

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
      return;
    }

    // A valid session with no real local store to go with it - e.g. a
    // login's password check succeeded but the device-verification OTP
    // failed to send before the app was closed/relaunched, leaving a
    // dangling session AuthService.login's own cleanup didn't get to run
    // for. Never fall through to ShellScreen with an empty/missing store id
    // - discovered 2026-08-22 chasing exactly that. Best-effort: a failed
    // sign-out must not block getting back to a clean WelcomeScreen.
    final config = await ref.read(storeConfigRepositoryProvider).get();
    if (!mounted) return;
    if (config == null || config.storeId.isEmpty) {
      try {
        await SupabaseService.supabaseClient.auth.signOut(
          scope: SignOutScope.global,
        );
      } catch (_) {}
      if (!mounted) return;
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
    // Restores the app-wide default the moment this screen leaves the tree
    // (pushReplacement disposes it once the next route has fully
    // transitioned in), so nothing else has to remember to do this.
    SystemChrome.setSystemUIOverlayStyle(lightScreenStatusBar);
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
