import 'package:flutter/material.dart';

import 'features/shell/shell_screen.dart';
import 'shared/theme/app_theme.dart';

/// Root widget of the PocketTill app.
class PocketTillApp extends StatelessWidget {
  const PocketTillApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketTill',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const ShellScreen(),
    );
  }
}
