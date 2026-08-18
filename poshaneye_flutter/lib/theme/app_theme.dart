import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Palette (Matching poshaneye zip specification)
  static const Color primary = Color(0xFF173124);          // Deep Forest Green
  static const Color primaryContainer = Color(0xFF2D4739); // Medium Dark Forest
  static const Color accentMint = Color(0xFFCAE8C9);        // Soft Mint Green
  static const Color accentSage = Color(0xFF4F6951);        // Sage Green
  static const Color darkGreenText = Color(0xFF07200E);

  // Surface & Card Palette
  static const Color background = Color(0xFFFAF9F5);        // Warm Cream Base
  static const Color cardBg = Color(0xFFEFEEEA);            // Soft Gray/Beige Card
  static const Color cardBgAlt = Color(0xFFF4F4F0);         // Light Soft Card
  static const Color vitalsCardBg = Color(0xFFDBE5DA);      // Sage Mint Vitals Card
  static const Color borderColor = Color(0xFFE3E2DF);       // Border Neutral
  static const Color borderAccent = Color(0xFFCCEACC);      // Border Mint Accent

  // Typography & Status Colors
  static const Color textPrimary = Color(0xFF1B1C1A);      // Charcoal Primary
  static const Color textSecondary = Color(0xFF424844);    // Muted Dark Neutral
  static const Color textMuted = Color(0xFF727973);        // Light Muted Neutral
  static const Color globeGreen = Color(0xFF3FFF80);       // Vanta Globe Electric Green

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: Colors.white,
        secondary: accentSage,
        onSecondary: Colors.white,
        secondaryContainer: accentMint,
        onSecondaryContainer: darkGreenText,
        surface: background,
        onSurface: textPrimary,
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: textPrimary),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
