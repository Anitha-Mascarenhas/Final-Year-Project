import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary palette
  static const Color primary = Color(0xFF1B6D24);
  static const Color primaryContainer = Color(0xFF4CAF50);
  static const Color onPrimary = Colors.white;
  static const Color primaryFixed = Color(0xFFD4EDDA);

  // Secondary palette
  static const Color secondary = Color(0xFF2E7D32);
  static const Color secondaryContainer = Color(0xFFA5D6A7);
  static const Color onSecondaryContainer = Color(0xFF1B5E20);
  static const Color secondaryFixed = Color(0xFF88D982);

  // Tertiary
  static const Color tertiaryContainer = Color(0xFFE8F5E9);
  static const Color onTertiaryContainer = Color(0xFF2E7D32);
  static const Color tertiaryFixed = Color(0xFFB2DFDB);

  // Surface / Background
  static const Color surface = Color(0xFFF8FAF8);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF1F5F1);
  static const Color surfaceContainerHigh = Color(0xFFE0E8E0);
  static const Color surfaceContainerHighest = Color(0xFFD4DDD4);

  // On Surface
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color onSurfaceVariant = Color(0xFF49454F);
  static const Color outline = Color(0xFF79747E);
  static const Color outlineVariant = Color(0xFFCAC4D0);

  // Error
  static const Color error = Color(0xFFB00020);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimary,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: Color(0xFF00796B),
        onTertiary: Colors.white,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: error,
        onError: Colors.white,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceContainerHighest,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFF313033),
        onInverseSurface: Color(0xFFF4EFF4),
        inversePrimary: Color(0xFFD0BCFF),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
        displayMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        headlineLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        headlineMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: primary,
          letterSpacing: -0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}
