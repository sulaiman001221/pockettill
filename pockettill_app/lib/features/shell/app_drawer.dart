import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../analytics/analytics_screen.dart';
import '../credit/credit_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/stock_screen.dart';

/// PocketTill's primary navigation drawer, opened from [CustomAppBar]'s
/// hamburger icon.
///
/// Stateless by design: Flutter's [Drawer] disposes its child's State once
/// its close animation finishes, so [activeRoute] and the navigation
/// callbacks are owned by the parent (`ShellScreen`) instead, which persists
/// across drawer close/reopen cycles.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.activeRoute,
    required this.onNavigate,
    required this.onNavigateWithoutTrackingActive,
    required this.onGoHome,
  });

  /// The currently active route ('stock', 'history', 'customers',
  /// 'analytics'), or anything else for no active highlight.
  final String activeRoute;

  /// Called when a tracked nav item (Stock/Sales History/Customers/
  /// Analytics) is tapped.
  final void Function(String route, Widget screen) onNavigate;

  /// Called when Settings is tapped - never updates [activeRoute].
  final void Function(Widget screen) onNavigateWithoutTrackingActive;

  /// Called when the header logo is tapped.
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            _Header(onLogoTap: onGoHome),
            const Divider(color: AppTheme.divider, height: 1),
            // Primary nav items sit at the top; Settings/Logout are pinned
            // near the bottom, just above the sync status row, regardless
            // of how much empty space is left in between.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stock',
                      isActive: activeRoute == 'stock',
                      onTap: () => onNavigate('stock', const StockScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Sales History',
                      isActive: activeRoute == 'history',
                      onTap: () =>
                          onNavigate('history', const HistoryScreen()),
                    ),
                    _MenuItem(
                      icon: Icons.people_outlined,
                      label: 'Customers',
                      isActive: activeRoute == 'customers',
                      onTap: () =>
                          onNavigate('customers', const CreditScreen()),
                      trailing: const _CreditBadge(),
                    ),
                    _MenuItem(
                      icon: Icons.bar_chart_outlined,
                      label: 'Analytics',
                      isActive: activeRoute == 'analytics',
                      onTap: () =>
                          onNavigate('analytics', const AnalyticsScreen()),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isActive: false,
                    onTap: () => onNavigateWithoutTrackingActive(
                      const SettingsScreen(),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    isActive: false,
                    iconColor: AppTheme.logoutRed,
                    labelColor: AppTheme.logoutRed,
                    onTap: () {}, // wired in Stage 13
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.divider, height: 1),
            const _SyncStatusRow(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLogoTap});

  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 24, right: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onLogoTap,
            child: Image.asset(
              'assets/images/pockettill_logo.png',
              height: 28,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            // Hardcoded for now - Stage 13 replaces this with StoreConfig.
            'Mommy Spaza Shop',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor =
        iconColor ?? (isActive ? AppTheme.primary : AppTheme.iconBorder);
    final resolvedLabelColor =
        labelColor ?? (isActive ? AppTheme.primary : AppTheme.textPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.drawerActiveBackground
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: resolvedIconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: resolvedLabelColor,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditBadge extends StatelessWidget {
  const _CreditBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'CREDIT',
        style: TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SyncStatusRow extends StatelessWidget {
  const _SyncStatusRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              // Hardcoded grey for now - Stage 12 wires this to SyncService.
              color: AppTheme.syncGrey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Not yet synced',
            style: TextStyle(fontSize: 12, color: AppTheme.syncGrey),
          ),
        ],
      ),
    );
  }
}
