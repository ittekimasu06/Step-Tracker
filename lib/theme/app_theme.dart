import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand metric colors - deliberately the SAME in light and dark; accent
  // colors don't invert, only neutrals do.
  static const Color stepsGreen = Color(0xFF4CAF50);
  static const Color stepsGreenDim = Color(0xFF1B5E20);
  static const Color activeBlue = Color(0xFF2196F3);
  static const Color activeBlueDim = Color(0xFF0D47A1);
  static const Color caloriesPurple = Color(0xFF9C27B0);
  static const Color caloriesPurpleDim = Color(0xFF4A148C);
  static const Color totalOrange = Color(0xFFFF9800);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceVariantDark = Color(0xFF242424);
  static const Color surfaceElevatedDark = Color(0xFF2C2C2C);

  // Light surfaces
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFECECEC);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);

  // Danger/error - NOT a mechanical inversion of the dark value (CF6679 is a
  // hue-bearing color tuned for contrast against near-black, not a neutral
  // gray) - this is Material's own light-theme error convention.
  static const Color _errorDark = Color(0xFFCF6679);
  static const Color _errorLight = Color(0xFFB3261E);

  /// Bright body text, one step down from `colorScheme.onSurface`. No
  /// existing Material role matches this shade - was `0xFFCCCCCC`.
  static Color textBright(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFCCCCCC)
          : const Color(0xFF404040);

  /// Muted/secondary text - the most common "description" gray. Was `0xFF888888`.
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF888888)
          : const Color(0xFF6B6B6B);

  /// Dim icon/label color, one step past [textSecondary]. Was `0xFF666666`.
  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF666666)
          : const Color(0xFF9A9A9A);

  /// Disabled/empty-state icon color, least emphasis. Was `0xFF444444`.
  static Color textDisabled(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF444444)
          : const Color(0xFFBDBDBD);

  /// A white-alpha overlay (subtle border/fill) reads correctly on a dark
  /// surface but disappears (white-on-white) on a light one. Flips to a
  /// black-alpha overlay in light mode so the same visual effect survives
  /// the theme switch.
  static Color overlay(BuildContext context, int alpha) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withAlpha(alpha)
          : Colors.black.withAlpha(alpha);

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
      error: _errorDark,
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
      primaryContainer: Color(0xFFC8E6C9),
      onPrimaryContainer: Color(0xFF1B5E20),
      secondary: activeBlue,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFBBDEFB),
      onSecondaryContainer: Color(0xFF0D47A1),
      tertiary: caloriesPurple,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE1BEE7),
      onTertiaryContainer: Color(0xFF4A148C),
      surface: surfaceLight,
      onSurface: Color(0xFF1A1A1A),
      surfaceContainerHighest: surfaceVariantLight,
      onSurfaceVariant: Color(0xFF616161),
      error: _errorLight,
      onError: Colors.white,
      outline: Color(0xFFBDBDBD),
      outlineVariant: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: backgroundLight,
    textTheme: GoogleFonts.manropeTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: Color(0xFF1A1A1A)),
        displayMedium: TextStyle(color: Color(0xFF1A1A1A)),
        displaySmall: TextStyle(color: Color(0xFF1A1A1A)),
        headlineLarge: TextStyle(color: Color(0xFF1A1A1A)),
        headlineMedium: TextStyle(color: Color(0xFF1A1A1A)),
        headlineSmall: TextStyle(color: Color(0xFF1A1A1A)),
        titleLarge: TextStyle(color: Color(0xFF1A1A1A)),
        titleMedium: TextStyle(color: Color(0xFF1A1A1A)),
        titleSmall: TextStyle(color: Color(0xFF1A1A1A)),
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF404040)),
        bodySmall: TextStyle(color: Color(0xFF616161)),
        labelLarge: TextStyle(color: Color(0xFF1A1A1A)),
        labelMedium: TextStyle(color: Color(0xFF404040)),
        labelSmall: TextStyle(color: Color(0xFF616161)),
      ),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    ),
    cardTheme: CardThemeData(
      color: surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return stepsGreen;
        return const Color(0xFFBDBDBD);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return stepsGreen.withAlpha(77);
        }
        return const Color(0xFFE0E0E0);
      }),
    ),
  );
}
