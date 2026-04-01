import 'package:flutter/material.dart';

class AppTheme {
  static const Color passGreen     = Color(0xFF4ADE80);
  static const Color failRed       = Color(0xFFF87171);
  static const Color warnAmber     = Color(0xFFFBBF24);
  static const Color bgDark        = Color(0xFF0D0F14);
  static const Color bgCard        = Color(0xFF111318);
  static const Color bgSurface     = Color(0xFF1A1D24);
  static const Color border        = Color(0xFF2A2D35);
  static const Color textPrimary   = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF888780);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        surface:   bgDark,
        primary:   passGreen,
        error:     failRed,
        secondary: warnAmber,
      ),
      cardColor: bgCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bgCard,
        indicatorColor: AppTheme.passGreen.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}