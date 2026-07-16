import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_service.dart';
import '../shell/shell_screen.dart';
import 'welcome_screen.dart';

/// The app's entry screen: shows the logo briefly while deciding where to
/// route. Deliberately just two outcomes, nothing remembered about past
/// registrations - a valid session goes straight into the app (even
/// offline, since PocketTill works fully offline once set up); anything
/// else always lands on WelcomeScreen. Login and Register both make their
/// own "no internet" check when actually submitting, so there's no need for
/// a separate connectivity gate here.
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

    if (loggedIn) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ShellScreen()));
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
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
