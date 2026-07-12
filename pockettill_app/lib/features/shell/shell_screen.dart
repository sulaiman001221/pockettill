import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../sales/sales_screen.dart';
import 'app_drawer.dart';

/// The app's root screen - always the base of the navigation stack. Shows
/// the drawer navigation shell wrapping [SalesScreen].
///
/// Owns the drawer's active-route tracking itself (rather than leaving it in
/// [AppDrawer]'s own state): Flutter's [Drawer] disposes its child's State
/// once its close animation finishes, so anything stored there is lost the
/// next time the drawer opens. [ShellScreen] persists for the app's whole
/// lifetime, so state lives here instead.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  String _activeRoute = 'sales';

  void _navigateTo(String route, Widget screen) {
    setState(() => _activeRoute = route);
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Settings and Logout never track as the active drawer item, so this
  /// leaves [_activeRoute] untouched.
  void _navigateWithoutTrackingActive(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _goHome() {
    setState(() => _activeRoute = 'sales');
    Navigator.of(context).pop();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showMenuIcon: true),
      drawer: AppDrawer(
        activeRoute: _activeRoute,
        onNavigate: _navigateTo,
        onNavigateWithoutTrackingActive: _navigateWithoutTrackingActive,
        onGoHome: _goHome,
      ),
      backgroundColor: AppTheme.background,
      // SalesScreen's fixed-height sections (scan card, search bar, checkout
      // bar) don't leave room to shrink when the keyboard appears; avoid
      // resizing the body for it rather than overflowing.
      resizeToAvoidBottomInset: false,
      body: const SalesScreen(),
    );
  }
}
