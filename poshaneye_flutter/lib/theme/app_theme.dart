import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
export 'app_colors.dart';

/// Design system font helpers for consistent typography.
class AppFonts {
  // Sora Bold 700 → major headings, large numbers, primary titles
  static TextStyle soraHeading({
    double fontSize = 26,
    Color color = AppColors.textDark,
    double? letterSpacing,
  }) =>
      GoogleFonts.sora(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: letterSpacing,
      );

  // Sora SemiBold 600 → card titles and important labels
  static TextStyle soraSemiBold({
    double fontSize = 16,
    Color color = AppColors.textDark,
  }) =>
      GoogleFonts.sora(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Sora 900 → large hero numbers
  static TextStyle soraBlack({
    double fontSize = 40,
    Color color = AppColors.textDark,
    String? fontFamily,
  }) =>
      GoogleFonts.sora(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color,
      );

  // Manrope Medium 500 → body text and descriptions
  static TextStyle manropeBody({
    double fontSize = 13,
    Color color = AppColors.textSecondary,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // Manrope Bold 700 → important buttons/actions
  static TextStyle manropeBold({
    double fontSize = 15,
    Color color = AppColors.textDark,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
      );

  // Space Grotesk SemiBold 600 → small labels, status labels, technical/measurement labels
  static TextStyle spaceGroteskLabel({
    double fontSize = 11,
    Color color = AppColors.textSecondary,
    double? letterSpacing,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: letterSpacing ?? 0.6,
      );
}

class AppTheme {
  static const Duration themeTransitionDuration = Duration(milliseconds: 350);
  static const Curve themeTransitionCurve = Curves.easeInOut;

  static ThemeData get lightTheme {
    // Use Manrope as the global base — most body text
    final baseTextTheme =
        GoogleFonts.manropeTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseTextTheme.copyWith(
        // Display / hero (large numbers, major headings) → Sora Bold 700
        displayLarge: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 57,
            color: AppColors.textDark),
        displayMedium: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 45,
            color: AppColors.textDark),
        displaySmall: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 36,
            color: AppColors.textDark),
        headlineLarge: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 32,
            color: AppColors.textDark),
        headlineMedium: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: AppColors.textDark),
        headlineSmall: GoogleFonts.sora(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: AppColors.textDark),
        // Titles → Sora SemiBold 600
        titleLarge: GoogleFonts.sora(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: AppColors.textDark),
        titleMedium: GoogleFonts.sora(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textDark),
        titleSmall: GoogleFonts.sora(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textDark),
        // Body → Manrope Medium 500
        bodyLarge: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: AppColors.textDark),
        bodyMedium: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.textSecondary),
        bodySmall: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AppColors.textSecondary),
        // Labels → Space Grotesk SemiBold 600
        labelLarge: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textSecondary),
        labelMedium: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.textSecondary),
        labelSmall: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: AppColors.textSecondary),
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryForest,
        onPrimary: Colors.white,
        secondary: AppColors.neonGreen,
        onSecondary: AppColors.textDark,
        surface: AppColors.background,
        onSurface: AppColors.textDark,
        error: Color(0xFFB42318),
        onError: Colors.white,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FluidPageTransitionsBuilder(),
          TargetPlatform.iOS: _FluidPageTransitionsBuilder(),
          TargetPlatform.windows: _FluidPageTransitionsBuilder(),
          TargetPlatform.macOS: _FluidPageTransitionsBuilder(),
          TargetPlatform.linux: _FluidPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _FluidPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardSurfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide:
              const BorderSide(color: AppColors.primaryForest, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryForest,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primaryForest,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final light = lightTheme;

    return light.copyWith(
      scaffoldBackgroundColor: const Color(0xFF14241B),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF2AE196),
        onPrimary: Color(0xFF0C2417),
        secondary: Color(0xFF2AE196),
        onSecondary: Color(0xFF0C2417),
        surface: Color(0xFF1D3528),
        onSurface: Color(0xFFE8F2EA),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
      ),
      textTheme: light.textTheme.apply(
        bodyColor: const Color(0xFFE8F2EA),
        displayColor: const Color(0xFFE8F2EA),
      ),
      cardTheme: light.cardTheme.copyWith(
        color: const Color(0xFF1D3528),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF34513F)),
        ),
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFF1D3528),
        labelStyle: const TextStyle(color: Color(0xFFA9C0B1)),
        hintStyle: const TextStyle(color: Color(0xFFA9C0B1)),
      ),
    );
  }
}

class AppThemeTransition extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const AppThemeTransition({
    super.key,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedTheme(
      data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      duration: AppTheme.themeTransitionDuration,
      curve: AppTheme.themeTransitionCurve,
      child: child,
    );
  }
}

class _FluidPageTransitionsBuilder extends PageTransitionsBuilder {
  const _FluidPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
