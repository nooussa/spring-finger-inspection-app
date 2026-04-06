import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales
  static const Color passGreen = Color(0xFF22C55E);
  static const Color failRed = Color(0xFFEF4444);
  static const Color warnOrange = Color(0xFFF97316);
  static const Color primaryBlue = Color(0xFF3B82F6);
  
  // Fond et surfaces (thème clair)
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color bgWhite = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  
  // Texte
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Couleurs de fond légères pour badges
  static const Color passBgLight = Color(0xFFDCFCE7);
  static const Color failBgLight = Color(0xFFFEE2E2);
  static const Color orangeBgLight = Color(0xFFFFF7ED);
  static const Color blueBgLight = Color(0xFFDBEAFE);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        surface: bgWhite,
        primary: primaryBlue,
        error: failRed,
        secondary: warnOrange,
      ),
      cardColor: bgWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }
}
