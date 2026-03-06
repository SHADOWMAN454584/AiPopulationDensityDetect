import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary dark theme
  static const Color backgroundDark = Color(0xFF0A0E21);
  static const Color surfaceDark = Color(0xFF1D1E33);
  static const Color cardDark = Color(0xFF1A1F38);

  // Primary light theme
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Accent colors
  static const Color neonGreen = Color(0xFF00E676);
  static const Color neonBlue = Color(0xFF00B0FF);
  static const Color neonPurple = Color(0xFF7C4DFF);
  static const Color neonCyan = Color(0xFF00E5FF);

  // Accent colors for light theme (slightly darker for contrast)
  static const Color accentGreenLight = Color(0xFF00C853);
  static const Color accentCyanLight = Color(0xFF00B8D4);

  // Gradient
  static const Color gradientStart = Color(0xFF0D1B2A);
  static const Color gradientMid = Color(0xFF1B2838);
  static const Color gradientEnd = Color(0xFF2A1B3D);

  // Light gradient
  static const Color gradientStartLight = Color(0xFFE8EAF6);
  static const Color gradientMidLight = Color(0xFFF3E5F5);
  static const Color gradientEndLight = Color(0xFFE1F5FE);

  // Status colors
  static const Color crowdLow = Color(0xFF00E676);
  static const Color crowdMedium = Color(0xFFFFD600);
  static const Color crowdHigh = Color(0xFFFF5252);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF607D8B);

  // Light text
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF616161);
  static const Color textMutedLight = Color(0xFF9E9E9E);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.neonGreen,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.neonGreen,
        secondary: AppColors.neonCyan,
        surface: AppColors.surfaceDark,
        error: AppColors.crowdHigh,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonGreen,
          foregroundColor: AppColors.backgroundDark,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.neonGreen, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIconColor: AppColors.neonGreen,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.neonGreen,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.accentGreenLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentGreenLight,
        secondary: AppColors.accentCyanLight,
        surface: AppColors.surfaceLight,
        error: AppColors.crowdHigh,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimaryLight,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentGreenLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.backgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.accentGreenLight,
            width: 2,
          ),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
        prefixIconColor: AppColors.accentGreenLight,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.accentGreenLight,
        unselectedItemColor: AppColors.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Theme-aware helpers
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? AppColors.textPrimary : AppColors.textPrimaryLight;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? AppColors.textSecondary : AppColors.textSecondaryLight;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? AppColors.textMuted : AppColors.textMutedLight;

  static Color cardColor(BuildContext context) =>
      isDark(context) ? AppColors.cardDark : AppColors.cardLight;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? AppColors.surfaceDark : AppColors.surfaceLight;

  static Color accentGreen(BuildContext context) =>
      isDark(context) ? AppColors.neonGreen : AppColors.accentGreenLight;

  static Color accentCyan(BuildContext context) =>
      isDark(context) ? AppColors.neonCyan : AppColors.accentCyanLight;

  static BoxDecoration get gradientBackground => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.gradientStart,
        AppColors.gradientMid,
        AppColors.gradientEnd,
      ],
    ),
  );

  static BoxDecoration get lightGradientBackground => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.gradientStartLight,
        AppColors.gradientMidLight,
        AppColors.gradientEndLight,
      ],
    ),
  );

  static BoxDecoration gradientBackgroundFor(BuildContext context) =>
      isDark(context) ? gradientBackground : lightGradientBackground;

  static BoxDecoration get cardGradient => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1F38), Color(0xFF2A1B3D)],
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: AppColors.neonPurple.withValues(alpha: 0.2),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration cardGradientFor(BuildContext context) => isDark(context)
      ? cardGradient
      : BoxDecoration(
          color: AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
}
