import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // THEME LOCK: dark — source: domain signal (fitness/health, night use, Samsung Health reference)
  // Scaffold.backgroundColor = AppTheme.backgroundDark — ALL screens

  // Brand metric colors
  static const Color stepsGreen = Color(0xFF4CAF50);
  static const Color stepsGreenDim = Color(0xFF1B5E20);
  static const Color activeBlue = Color(0xFF2196F3);
  static const Color activeBlueDim = Color(0xFF0D47A1);
  static const Color caloriesPurple = Color(0xFF9C27B0);
  static const Color caloriesPurpleDim = Color(0xFF4A148C);
  static const Color totalOrange = Color(0xFFFF9800);

  // Surfaces
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceVariantDark = Color(0xFF242424);
  static const Color surfaceElevatedDark = Color(0xFF2C2C2C);

  // Light surfaces (required getter)
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: stepsGreen,
      onPrimary: Colors.white,
      primaryContainer: stepsGreenDim,
      onPrimaryContainer: Color(0xFFE8F5E9),
      secondary: activeBlue,
      onSecondary: Colors.white,
      secondaryContainer: activeBlueDim,
      onSecondaryContainer: Color(0xFFE3F2FD),
      tertiary: caloriesPurple,
      onTertiary: Colors.white,
      tertiaryContainer: caloriesPurpleDim,
      onTertiaryContainer: Color(0xFFF3E5F5),
      surface: surfaceDark,
      onSurface: Color(0xFFE6E6E6),
      surfaceContainerHighest: surfaceVariantDark,
      onSurfaceVariant: Color(0xFFAAAAAA),
      error: Color(0xFFCF6679),
      onError: Colors.white,
      outline: Color(0xFF3A3A3A),
      outlineVariant: Color(0xFF2A2A2A),
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: GoogleFonts.manropeTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: Color(0xFFE6E6E6)),
        displayMedium: TextStyle(color: Color(0xFFE6E6E6)),
        displaySmall: TextStyle(color: Color(0xFFE6E6E6)),
        headlineLarge: TextStyle(color: Color(0xFFE6E6E6)),
        headlineMedium: TextStyle(color: Color(0xFFE6E6E6)),
        headlineSmall: TextStyle(color: Color(0xFFE6E6E6)),
        titleLarge: TextStyle(color: Color(0xFFE6E6E6)),
        titleMedium: TextStyle(color: Color(0xFFE6E6E6)),
        titleSmall: TextStyle(color: Color(0xFFE6E6E6)),
        bodyLarge: TextStyle(color: Color(0xFFE6E6E6)),
        bodyMedium: TextStyle(color: Color(0xFFCCCCCC)),
        bodySmall: TextStyle(color: Color(0xFFAAAAAA)),
        labelLarge: TextStyle(color: Color(0xFFE6E6E6)),
        labelMedium: TextStyle(color: Color(0xFFCCCCCC)),
        labelSmall: TextStyle(color: Color(0xFFAAAAAA)),
      ),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFE6E6E6)),
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE6E6E6),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2A2A2A),
      thickness: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return stepsGreen;
        return const Color(0xFF666666);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return stepsGreen.withAlpha(77);
        }
        return const Color(0xFF333333);
      }),
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: stepsGreen,
      onPrimary: Colors.white,
      secondary: activeBlue,
      surface: surfaceLight,
      onSurface: Color(0xFF1A1A1A),
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: GoogleFonts.manropeTextTheme(),
  );
}
