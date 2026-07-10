import 'package:flutter/material.dart';

import '../analytics/analytics_screen.dart';
import '../credit/credit_screen.dart';
import '../history/history_screen.dart';
import '../sales/sales_screen.dart';
import '../settings/settings_screen.dart';
import '../stock/stock_screen.dart';

/// The app's main navigation shell: a bottom-tab bar over the 5 primary
/// screens, plus a settings icon that pushes [SettingsScreen] on top.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
    _ShellTab(label: 'Sales', icon: Icons.point_of_sale, screen: SalesScreen()),
    _ShellTab(label: 'Stock', icon: Icons.inventory_2, screen: StockScreen()),
    _ShellTab(label: 'Credit', icon: Icons.people, screen: CreditScreen()),
    _ShellTab(
      label: 'History',
      icon: Icons.receipt_long,
      screen: HistoryScreen(),
    ),
    _ShellTab(
      label: 'Analytics',
      icon: Icons.bar_chart,
      screen: AnalyticsScreen(),
    ),
  ];

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketTill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [for (final tab in _tabs) tab.screen],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          for (final tab in _tabs)
            BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final Widget screen;
}
