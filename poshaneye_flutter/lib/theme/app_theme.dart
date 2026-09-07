import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ════════════════════════════════════════════════════════════════════
// THEME PROVIDER — InheritedWidget for app-wide theme state
// ════════════════════════════════════════════════════════════════════

class ThemeProvider extends InheritedWidget {
  final ThemeMode themeMode;
  final VoidCallback toggleTheme;

  const ThemeProvider({
    super.key,
    required this.themeMode,
    required this.toggleTheme,
    required super.child,
  });

  bool get isDark => themeMode == ThemeMode.dark;

  static ThemeProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
    assert(provider != null, 'No ThemeProvider found in context');
    return provider!;
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return themeMode != oldWidget.themeMode;
  }
}

// ════════════════════════════════════════════════════════════════════
// APP THEME — Refined Blue Palette
// ════════════════════════════════════════════════════════════════════

class AppTheme {
  // ── Brand Palette (shared blue accent) ──────────────────────────
  static const Color primary = Color(0xFF2563EB);        // Refined Blue
  static const Color primaryDark = Color(0xFF1D4ED8);    // Deeper Blue
  static const Color primaryLight = Color(0xFF3B82F6);   // Lighter Blue
  static const Color primaryContainer = Color(0xFFDBEAFE); // Light Blue Container
  static const Color accentBlue = Color(0xFF60A5FA);     // Soft Blue Accent
  static const Color accentMint = Color(0xFFDBEAFE);     // Light Blue Tint
  static const Color accentSage = Color(0xFF1E40AF);     // Dark Blue Accent
  static const Color darkText = Color(0xFF0F172A);       // Navy Text

  // ── Dark mode colors ────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0A0F1A);  // Near-black with navy
  static const Color darkSurface = Color(0xFF111827);     // Dark charcoal
  static const Color darkCard = Color(0xFF1F2937);        // Dark card
  static const Color darkCardAlt = Color(0xFF253042);     // Slightly lighter
  static const Color darkVitalsCard = Color(0xFF1E293B);  // Slate dark
  static const Color darkBorder = Color(0xFF334155);      // Slate border
  static const Color darkBorderAccent = Color(0xFF1E3A5F); // Blue-dark border
  static const Color darkTextPrimary = Color(0xFFF1F5F9); // Off-white
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Light gray
  static const Color darkTextMuted = Color(0xFF64748B);   // Muted gray

  // ── Light mode colors ───────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8FAFC);  // Very light gray
  static const Color lightSurface = Color(0xFFFFFFFF);     // White
  static const Color lightCard = Color(0xFFFFFFFF);        // White
  static const Color lightCardAlt = Color(0xFFF1F5F9);     // Light slate
  static const Color lightVitalsCard = Color(0xFFEFF6FF);  // Very light blue
  static const Color lightBorder = Color(0xFFE2E8F0);      // Slate border
  static const Color lightBorderAccent = Color(0xFFBFDBFE); // Light blue border
  static const Color lightTextPrimary = Color(0xFF0F172A);  // Navy
  static const Color lightTextSecondary = Color(0xFF475569); // Slate
  static const Color lightTextMuted = Color(0xFF94A3B8);    // Muted

  // ── Accent Colors (shared) ──────────────────────────────────────
  static const Color accentGreen = Color(0xFF22C55E);     // Success green
  static const Color accentRed = Color(0xFFEF4444);       // Error red
  static const Color navDarkBg = Color(0xFF111827);       // Dark nav
  static const Color navLightBg = Color(0xFFFFFFFF);      // White nav

  // ════════════════════════════════════════════════════════════════════
  // THEME ACCESSORS — use these throughout the app
  // ════════════════════════════════════════════════════════════════════

  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color cardBgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCard;
  }

  static Color cardBgAltColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCardAlt
        : lightCardAlt;
  }

  static Color vitalsCardBgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkVitalsCard
        : lightVitalsCard;
  }

  static Color borderColorValue(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }

  static Color borderAccentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorderAccent
        : lightBorderAccent;
  }

  static Color textColorPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color textColorSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  static Color textColorMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextMuted
        : lightTextMuted;
  }

  static Color navBgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? navDarkBg
        : navLightBg;
  }

  static Color navBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? primary.withValues(alpha: 0.2)
        : primary.withValues(alpha: 0.1);
  }

  static Color navActiveColor(BuildContext context) {
    return primary;
  }

  static Color navInactiveColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white54
        : Colors.black45;
  }

  static Color scaffoldBgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color iconBtnBgColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCardAlt;
  }

  static Color fabBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  // ════════════════════════════════════════════════════════════════════
  // LIGHT THEME — Blue + White
  // ════════════════════════════════════════════════════════════════════

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: primaryDark,
        secondary: accentSage,
        onSecondary: Colors.white,
        secondaryContainer: lightVitalsCard,
        onSecondaryContainer: primaryDark,
        surface: lightBackground,
        onSurface: lightTextPrimary,
        error: accentRed,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: lightTextPrimary),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: lightTextPrimary),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: lightTextPrimary),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: lightTextPrimary),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: lightTextPrimary),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: lightTextPrimary),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: lightTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DARK THEME — Black + Blue
  // ════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primaryLight,
        onPrimary: darkBackground,
        primaryContainer: primaryDark,
        onPrimaryContainer: Colors.white,
        secondary: accentBlue,
        onSecondary: darkBackground,
        secondaryContainer: darkVitalsCard,
        onSecondaryContainer: primaryLight,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: accentRed,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w800, color: darkTextPrimary),
        displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: darkTextPrimary),
        headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w700, color: darkTextPrimary),
        headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w700, color: darkTextPrimary),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: darkTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
