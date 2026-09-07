import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable animated grid background with subtle grid lines,
/// intersection dots, and ambient glow effect.
/// Automatically adapts to light/dark theme.
class AnimatedGridBackground extends StatefulWidget {
  final Color? baseColor;
  final Color? accentColor;
  final Color? dotColor;
  final double gridSpacing;
  final double dotRadius;
  final double lineOpacity;

  const AnimatedGridBackground({
    super.key,
    this.baseColor,
    this.accentColor,
    this.dotColor,
    this.gridSpacing = 40.0,
    this.dotRadius = 1.5,
    this.lineOpacity = 0.06,
  });

  @override
  State<AnimatedGridBackground> createState() => _AnimatedGridBackgroundState();
}

class _AnimatedGridBackgroundState extends State<AnimatedGridBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware colors for blue theme
    final baseColor = widget.baseColor ??
        (isDark ? AppTheme.darkBackground : AppTheme.lightBackground);
    final accentColor = widget.accentColor ??
        (isDark ? AppTheme.primaryLight : AppTheme.primary);
    final dotColor = widget.dotColor ??
        (isDark ? AppTheme.primaryLight : AppTheme.primary);
    final lineOpacity = isDark ? widget.lineOpacity : 0.06;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _GridPainter(
              animationValue: _controller.value,
              baseColor: baseColor,
              accentColor: accentColor,
              dotColor: dotColor,
              gridSpacing: widget.gridSpacing,
              dotRadius: widget.dotRadius,
              lineOpacity: lineOpacity,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;
  final Color accentColor;
  final Color dotColor;
  final double gridSpacing;
  final double dotRadius;
  final double lineOpacity;
  final bool isDark;

  _GridPainter({
    required this.animationValue,
    required this.baseColor,
    required this.accentColor,
    required this.dotColor,
    required this.gridSpacing,
    required this.dotRadius,
    required this.lineOpacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = baseColor,
    );

    // Draw subtle ambient glow
    _drawAmbientGlow(canvas, size);

    // Draw grid lines
    _drawGridLines(canvas, size);

    // Draw intersection dots
    _drawIntersectionDots(canvas, size);
  }

  void _drawAmbientGlow(Canvas canvas, Size size) {
    // Subtle moving glow effect - blue accent
    final glowCenterX =
        size.width * (0.3 + 0.4 * math.sin(animationValue * 2 * math.pi));
    final glowCenterY =
        size.height * (0.3 + 0.4 * math.cos(animationValue * 2 * math.pi));

    final glowAlpha = isDark ? 0.025 : 0.03;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (glowCenterX / size.width) * 2 - 1,
          (glowCenterY / size.height) * 2 - 1,
        ),
        radius: 0.6,
        colors: [
          accentColor.withValues(alpha: glowAlpha),
          accentColor.withValues(alpha: glowAlpha * 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width * 0.6,
      ));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      glowPaint,
    );

    // Second subtle glow
    final glowCenterX2 =
        size.width * (0.7 - 0.3 * math.cos(animationValue * 2 * math.pi));
    final glowCenterY2 =
        size.height * (0.6 + 0.3 * math.sin(animationValue * 2 * math.pi));

    final coolColor = isDark
        ? const Color(0xFF3B82F6)  // Blue
        : const Color(0xFF60A5FA);  // Lighter blue

    final blueGlowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          (glowCenterX2 / size.width) * 2 - 1,
          (glowCenterY2 / size.height) * 2 - 1,
        ),
        radius: 0.5,
        colors: [
          coolColor.withValues(alpha: isDark ? 0.015 : 0.02),
          coolColor.withValues(alpha: isDark ? 0.004 : 0.006),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: size.width * 0.5,
      ));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      blueGlowPaint,
    );
  }

  void _drawGridLines(Canvas canvas, Size size) {
    // Blue-tinted grid lines
    final lineColor = isDark
        ? AppTheme.primaryLight.withValues(alpha: lineOpacity * 0.6)
        : AppTheme.primary.withValues(alpha: lineOpacity * 0.5);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;

    // Vertical lines
    for (double x = 0; x <= size.width; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        linePaint,
      );
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  void _drawIntersectionDots(Canvas canvas, Size size) {
    final dotAlphaBase = isDark ? 0.12 : 0.1;
    final dotPaint = Paint()..color = dotColor.withValues(alpha: dotAlphaBase);

    // Use a fixed seed for consistent dot placement
    final math.Random random = math.Random(42);

    for (double x = 0; x <= size.width; x += gridSpacing) {
      for (double y = 0; y <= size.height; y += gridSpacing) {
        // ~40% of intersections get a dot
        if (random.nextDouble() < 0.4) {
          // Subtle brightness variation
          final brightness = 0.06 + random.nextDouble() * 0.1;
          dotPaint.color = dotColor.withValues(alpha: brightness);

          canvas.drawCircle(
            Offset(x, y),
            dotRadius,
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}
