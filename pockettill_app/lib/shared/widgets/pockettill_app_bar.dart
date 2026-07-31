import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// PocketTill's shared top app bar.
///
/// Shows a hamburger icon that opens the drawer ([showMenuIcon] true, used
/// by the shell) or a back arrow that pops the current route ([showMenuIcon]
/// false, used by every pushed screen). The centre shows the PocketTill
/// icon by default, or [title] when provided. The trailing icon is a
/// notification bell by default (not yet wired to anything); pass
/// [trailingIcon]/[onTrailingTap] together to replace it for a screen that
/// has a more relevant action there.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.showMenuIcon = true,
    this.title,
    this.trailingIcon,
    this.onTrailingTap,
  });

  final bool showMenuIcon;
  final String? title;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              _Leading(showMenuIcon: showMenuIcon),
              Expanded(child: Center(child: _Centre(title: title))),
              IconButton(
                icon: Icon(
                  trailingIcon ?? Icons.notifications_none,
                  color: AppTheme.textPrimary,
                  size: 28,
                ),
                onPressed: onTrailingTap ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class _Leading extends StatelessWidget {
  const _Leading({required this.showMenuIcon});

  final bool showMenuIcon;

  @override
  Widget build(BuildContext context) {
    if (showMenuIcon) {
      return IconButton(
        icon: const _HamburgerIcon(),
        onPressed: () => Scaffold.of(context).openDrawer(),
      );
    }
    if (!Navigator.of(context).canPop()) {
      // Reached via pushReplacement (e.g. SplashScreen routing straight to
      // LoginScreen for a registered-but-logged-out device) - there's
      // nothing to pop back to, so a back arrow that pops would leave a
      // blank Navigator. Keep the same footprint so the centred title
      // doesn't shift, just make it inert instead.
      return const SizedBox(width: 48, height: 48);
    }
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

/// A custom 3-bar hamburger glyph (rather than [Icons.menu]) so the spacing
/// between bars and the shorter middle bar can be tuned precisely.
class _HamburgerIcon extends StatelessWidget {
  const _HamburgerIcon();

  static const double _barHeight = 2.4;
  static const double _fullBarWidth = 26;
  static const double _shortBarWidth = 18;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width) {
      return Container(
        width: width,
        height: _barHeight,
        decoration: BoxDecoration(
          color: AppTheme.textPrimary,
          borderRadius: BorderRadius.circular(_barHeight / 2),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bar(_fullBarWidth),
        const SizedBox(height: _gap),
        bar(_shortBarWidth),
        const SizedBox(height: _gap),
        bar(_fullBarWidth),
      ],
    );
  }
}

class _Centre extends StatelessWidget {
  const _Centre({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    if (title != null) {
      return Text(
        title!,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      );
    }
    return Image.asset('assets/images/pockettill_icon.png', height: 34);
  }
}
