import 'package:flutter/material.dart';

/// PocketTill's brand colours and base light theme.
class AppTheme {
  AppTheme._();

  // Brand colours
  static const Color primary = Color(0xFF5170FF); // drawer active states, badges, scan button
  static const Color background = Color(0xFFF4F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1C1E);
  static const Color textSecondary = Color(0xFF787B86);
  static const Color iconBorder = Color(0xFF6B7280);
  static const Color actionDark = Color(0xFF374151);
  static const Color checkoutButtonBackground = Color(0xFFD1D5DB);
  static const Color searchPlaceholder = Color(0xFF9CA3AF);
  static const Color logoutRed = Color(0xFFE53E3E);
  static const Color syncGreen = Color(0xFF38A169);
  static const Color syncAmber = Color(0xFFD69E2E);
  static const Color syncGrey = Color(0xFFA0AEC0);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color drawerActiveBackground = Color(0xFFEEF1FF);
  static const Color cardBlue = Color(0xFF3B82F6); // Card payment type
  static const Color creditPurple = Color(0xFF8B5CF6); // Credit payment type

  // Typography
  static const TextStyle mainTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle bodySubtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );
  static const TextStyle searchPlaceholderStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: searchPlaceholder,
  );
  static const TextStyle buttonText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
  static const TextStyle totalLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: iconBorder,
  );
  static const TextStyle totalValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary),
        ),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
    );
  }
}
